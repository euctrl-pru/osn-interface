# Build the SELECT body for a states view, applying an optional temporal
# downsample. `downsample_s` keeps only rows where `time %% downsample_s == 0`,
# which mirrors pyopensky's Trino `history()` reduction to e.g. 5-second
# updates. `NULL`, `0` or `1` disables downsampling (keeps every row).
osn_select_sql <- function(read_expr, downsample_s = NULL) {
  if (!is.null(downsample_s) && downsample_s > 1) {
    downsample_s <- as.integer(downsample_s)
    sprintf("SELECT * FROM %s WHERE time %% %d = 0", read_expr, downsample_s)
  } else {
    sprintf("SELECT * FROM %s", read_expr)
  }
}

#' Lazily fetch state vectors for a single day
#'
#' Returns a lazy `dbplyr` table of one day's state vectors. No data is
#' transferred until you call [dplyr::collect()], [head()], or similar. The
#' source recorded on `con` (see [osn_connect()]) selects the backend:
#'
#' * `"osn-ec-datadump"` — a DuckDB view over the remote parquet files in the
#'   OSN S3 bucket.
#' * `"osn-historical-trino"` — the day is queried from the OSN Trino endpoint
#'   and registered into DuckDB as a lazy table.
#'
#' Either way the returned object is a lazy `tbl_dbi` with identical schema.
#'
#' @param date Date to fetch. Default: yesterday (`Sys.Date() - 1`).
#' @param con A DBI connection from [osn_connect()]. If `NULL`, a new
#'   connection is created automatically.
#' @param downsample_s Optional integer. Keep only state vectors whose Unix
#'   `time` is a multiple of this many seconds (`time %% downsample_s == 0`),
#'   reducing the update rate. Default `5` (5-second updates), matching
#'   pyopensky's behaviour. Set to `NULL`, `0`, or `1` to keep every row.
#' @param bbox Optional bounding box (list with `lat_min`, `lat_max`, `lon_min`,
#'   `lon_max`) to pre-filter server-side. For the `"osn-historical-trino"`
#'   source this is pushed into the Trino query so only rows inside the box are
#'   transferred — important for performance, as an unfiltered day is very
#'   large. Ignored by the `"osn-ec-datadump"` source (which prunes via the
#'   later [osn_filter_radius()] parquet pushdown). Usually set indirectly via
#'   [osn_fetch_around_airport()].
#' @return A lazy `tbl_dbi` (dbplyr table).
#' @export
osn_fetch_day <- function(date = Sys.Date() - 1, con = NULL, downsample_s = 5,
                          bbox = NULL) {
  if (is.null(con)) con <- osn_connect()

  if (osn_source(con) == "osn-historical-trino") {
    return(osn_fetch_day_trino(date, con, downsample_s = downsample_s, bbox = bbox))
  }

  date_str <- format(as.Date(date), "%Y-%m-%d")
  s3_glob  <- sprintf(
    "s3://ec-datadump/%s/*/states_%s-*.parquet",
    date_str, date_str
  )

  view_name <- sprintf("sv_%s", gsub("-", "", date_str))
  read_expr <- sprintf("read_parquet('%s')", s3_glob)
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE VIEW %s AS %s",
    view_name, osn_select_sql(read_expr, downsample_s)
  ))

  dplyr::tbl(con, view_name)
}

#' Lazily fetch state vectors for a date range
#'
#' Convenience wrapper around [osn_fetch_day()] that spans multiple days.
#'
#' @param from Start date (inclusive).
#' @param to End date (inclusive).
#' @param con A DBI connection from [osn_connect()]. If `NULL`, a new
#'   connection is created automatically.
#' @param downsample_s Optional integer. Keep only state vectors whose Unix
#'   `time` is a multiple of this many seconds (`time %% downsample_s == 0`).
#'   Default `5`. Set to `NULL`, `0`, or `1` to keep every row.
#' @param bbox Optional bounding box (see [osn_fetch_day()]) pushed into the
#'   Trino query for the `"osn-historical-trino"` source.
#' @return A lazy `tbl_dbi` (dbplyr table).
#' @export
osn_fetch_days <- function(from, to, con = NULL, downsample_s = 5, bbox = NULL) {
  if (is.null(con)) con <- osn_connect()

  from  <- as.Date(from)
  to    <- as.Date(to)
  dates <- seq(from, to, by = "day")

  if (osn_source(con) == "osn-historical-trino") {
    return(osn_fetch_days_trino(dates, con, downsample_s = downsample_s, bbox = bbox))
  }

  globs <- sprintf(
    "'s3://ec-datadump/%s/*/states_%s-*.parquet'",
    format(dates, "%Y-%m-%d"), format(dates, "%Y-%m-%d")
  )
  glob_list <- paste(globs, collapse = ", ")

  view_name <- sprintf("sv_%s_%s", format(from, "%Y%m%d"), format(to, "%Y%m%d"))
  read_expr <- sprintf("read_parquet([%s])", glob_list)
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE VIEW %s AS %s",
    view_name, osn_select_sql(read_expr, downsample_s)
  ))

  dplyr::tbl(con, view_name)
}
