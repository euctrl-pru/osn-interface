# Historical Trino source -----------------------------------------------------
#
# The "osn-historical-trino" source reaches the OpenSky Network Trino endpoint
# (trino.opensky-network.org, catalog `minio`, schema `osky`) — the same
# backend the Python pyopensky/traffic libraries use — via the native R Trino
# client RPresto. Unlike the "osn-ec-datadump" source, this does NOT go through
# DuckDB's S3 client; Trino uses HTTP + basic auth (OPENSKY_USERNAME /
# OPENSKY_PASSWORD), which is a different protocol than S3 key signing.
#
# To keep the package's lazy-`dbplyr`-tbl contract, the Trino result is pulled
# into R and registered into the companion DuckDB connection as a view, so
# downstream helpers (osn_filter_radius(), collect(), ...) work identically for
# both sources.

# RPresto's PrestoConnection does not implement DBI::dbIsValid(), which errors
# with "unable to find an inherited method". Treat any object where the check
# is unavailable or errors as still valid (the query will surface a real
# connection error if it is not).
osn_dbi_valid <- function(con) {
  ok <- tryCatch(DBI::dbIsValid(con), error = function(e) NA)
  if (is.na(ok)) TRUE else isTRUE(ok)
}

# Trino connection details for the OSN state-vector table.
osn_trino_host    <- "https://trino.opensky-network.org"
osn_trino_port    <- 443L
osn_trino_catalog <- "minio"
osn_trino_schema  <- "osky"
# Fully-qualified state-vectors table in the OSN Trino catalog.
osn_trino_table   <- "minio.osky.state_vectors_data4"

#' Open a connection to the OpenSky Network Trino endpoint
#'
#' Connects to `trino.opensky-network.org` (catalog `minio`, schema `osky`)
#' using the native R Trino client `RPresto`. OpenSky's Trino endpoint uses
#' OAuth2 external authentication (the same browser-based flow as
#' `trino --external-authentication`): on first use a browser window opens for
#' you to log in with your OpenSky account; the resulting bearer token is cached
#' on disk and reused until it expires. This is the backend used by the
#' `"osn-historical-trino"` source (see [osn_connect()]).
#'
#' The `OPENSKY_USERNAME` environment variable is used as the Trino user tag
#' (`X-Trino-User`); the actual authentication happens via the browser login,
#' not `OPENSKY_PASSWORD`.
#'
#' Requires the `RPresto`, `httr` and `jsonlite` packages (in Suggests); install
#' them with `install.packages(c("RPresto", "httr", "jsonlite"))` if missing.
#'
#' @param force_login Logical. If `TRUE`, ignore any cached token and force a
#'   fresh browser login.
#' @return A `PrestoConnection` (DBI connection) to the OSN Trino server.
#' @export
osn_trino_connect <- function(force_login = FALSE) {
  if (!requireNamespace("RPresto", quietly = TRUE) ||
      !requireNamespace("httr", quietly = TRUE) ||
      !requireNamespace("jsonlite", quietly = TRUE)) {
    stop(
      "The \"osn-historical-trino\" source requires the 'RPresto', 'httr' and 'jsonlite' packages.\n",
      "Install them with: install.packages(c(\"RPresto\", \"httr\", \"jsonlite\"))"
    )
  }

  user <- Sys.getenv("OPENSKY_USERNAME")
  if (user == "") user <- "osninterface"  # only a tag; auth is via OAuth2 token.

  # Acquire an OAuth2 bearer token (cached, or via interactive browser login),
  # and have RPresto attach it as an Authorization header on every request.
  token <- osn_trino_get_token(force = force_login)

  DBI::dbConnect(
    RPresto::Presto(),
    use.trino.headers = TRUE,
    host    = osn_trino_host,
    port    = osn_trino_port,
    user    = user,
    catalog = osn_trino_catalog,
    schema  = osn_trino_schema,
    source  = "osninterface",
    request.config = httr::add_headers(
      Authorization = paste("Bearer", token)
    )
  )
}

# Midnight-UTC Unix timestamp for a date.
osn_day_start <- function(date) {
  as.integer(as.numeric(as.POSIXct(paste0(as.Date(date), " 00:00:00"), tz = "UTC")))
}

# Build a Trino SQL query over a Unix-time window [start, end).
#
# The OSN Trino table `osky.state_vectors_data4` is partitioned by an `hour`
# column (a Unix timestamp floored to the hour); Trino *requires* a predicate on
# it, so we always constrain `hour` to the same window as `time`. `time` and
# `hour` are Unix timestamps (seconds). Optionally downsamples
# (time %% downsample_s == 0) and pre-filters to a bounding box.
osn_trino_window_sql <- function(start, end, downsample_s = 5, bbox = NULL) {
  # Align the hour lower bound down to the hour so the first partition is kept.
  hour_start <- start - (start %% 3600L)

  where <- c(
    sprintf("hour >= %d", hour_start), sprintf("hour < %d", end),
    sprintf("time >= %d", start),      sprintf("time < %d", end)
  )
  if (!is.null(downsample_s) && downsample_s > 1) {
    where <- c(where, sprintf("time %% %d = 0", as.integer(downsample_s)))
  }
  if (!is.null(bbox)) {
    where <- c(
      where,
      sprintf("lat >= %f", bbox$lat_min), sprintf("lat <= %f", bbox$lat_max),
      sprintf("lon >= %f", bbox$lon_min), sprintf("lon <= %f", bbox$lon_max)
    )
  }

  sprintf("SELECT * FROM %s WHERE %s", osn_trino_table, paste(where, collapse = " AND "))
}

# Single-day convenience wrapper around osn_trino_window_sql().
osn_trino_day_sql <- function(date, downsample_s = 5, bbox = NULL) {
  start <- osn_day_start(date)
  osn_trino_window_sql(start, start + 24L * 3600L, downsample_s = downsample_s, bbox = bbox)
}

# Get (or lazily open) the companion Trino connection stored on `con`.
osn_trino_con_for <- function(con) {
  tcon <- attr(con, "osn_trino_con", exact = TRUE)
  if (is.null(tcon) || !osn_dbi_valid(tcon)) {
    tcon <- osn_trino_connect()
    attr(con, "osn_trino_con") <- tcon
  }
  tcon
}

# Fetch one day from Trino and register it into the companion DuckDB connection
# as a view, returning a lazy tbl. `con` is the DuckDB connection created by
# osn_connect(source = "osn-historical-trino").
osn_fetch_day_trino <- function(date, con, downsample_s = 5, bbox = NULL) {
  tcon <- osn_trino_con_for(con)
  sql  <- osn_trino_day_sql(date, downsample_s = downsample_s, bbox = bbox)
  df   <- DBI::dbGetQuery(tcon, sql)

  view_name <- sprintf("sv_%s", format(as.Date(date), "%Y%m%d"))
  duckdb::duckdb_register(con, view_name, df, overwrite = TRUE)

  dplyr::tbl(con, view_name)
}

# Fetch a contiguous range of days from Trino in a single query and register
# the result into DuckDB as a lazy tbl. `dates` is a vector of Date objects
# (assumed contiguous, ascending); only its first and last elements bound the
# query.
osn_fetch_days_trino <- function(dates, con, downsample_s = 5, bbox = NULL) {
  tcon  <- osn_trino_con_for(con)
  from  <- min(dates)
  to    <- max(dates)
  start <- osn_day_start(from)
  end   <- osn_day_start(to) + 24L * 3600L

  sql <- osn_trino_window_sql(start, end, downsample_s = downsample_s, bbox = bbox)
  df  <- DBI::dbGetQuery(tcon, sql)

  view_name <- sprintf("sv_%s_%s", format(from, "%Y%m%d"), format(to, "%Y%m%d"))
  duckdb::duckdb_register(con, view_name, df, overwrite = TRUE)

  dplyr::tbl(con, view_name)
}
