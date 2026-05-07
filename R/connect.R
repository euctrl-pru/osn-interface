#' Create a DuckDB connection configured for OpenSky Network S3
#'
#' Initialises a DuckDB connection, installs/loads the `httpfs` and `spatial`
#' extensions, and configures S3 access to the OSN bucket using the
#' `OSN_USERNAME` and `OSN_KEY` environment variables.
#'
#' @param proxy Logical. If `TRUE`, configures DuckDB to route through a
#'   corporate HTTP proxy. Proxy URL and password are parsed from the
#'   `HTTPS_PROXY` environment variable (expected format:
#'   `http://user:password@@host:port`). The proxy username is taken from the
#'   Windows session username. Extensions are force-installed to a local
#'   directory and additional extensions (`ui`, `h3`) are installed.
#' @return A DBI connection object.
#' @export
osn_connect <- function(proxy = FALSE) {
  con <- DBI::dbConnect(duckdb::duckdb())

  if (proxy) {
    https_proxy <- Sys.getenv("HTTPS_PROXY")
    if (https_proxy == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("HTTPS_PROXY environment variable must be set when proxy = TRUE.")
    }

    parsed <- regmatches(
      https_proxy,
      regexec("^(https?://)(?:([^:]+):([^@]+)@)?(.+)$", https_proxy, perl = TRUE)
    )[[1]]
    if (length(parsed) < 5 || parsed[5] == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("Could not parse HTTPS_PROXY. Expected format: http://[user:pass@]host:port")
    }

    proxy_url      <- paste0(parsed[2], parsed[5])
    proxy_password <- parsed[4]
    proxy_username <- Sys.getenv("USERNAME")

    if (proxy_password == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("HTTPS_PROXY must include credentials (http://user:pass@host:port).")
    }

    ext_dir <- file.path("C:/Users", proxy_username, "dev/duckdb_ext")
    DBI::dbExecute(con, sprintf("SET extension_directory = '%s';", ext_dir))
    DBI::dbExecute(con, sprintf("SET http_proxy = '%s';", proxy_url))
    DBI::dbExecute(con, sprintf("SET http_proxy_username = '%s';", proxy_username))
    DBI::dbExecute(con, sprintf("SET http_proxy_password = '%s';", proxy_password))

    DBI::dbExecute(con, "FORCE INSTALL httpfs; LOAD httpfs;")
    DBI::dbExecute(con, "FORCE INSTALL spatial; LOAD spatial;")

    extensions <- DBI::dbGetQuery(
      con, "SELECT extension_name, installed, description FROM duckdb_extensions();"
    )
    message("Installed DuckDB extensions:")
    print(extensions)
  } else {
    DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
    DBI::dbExecute(con, "INSTALL spatial; LOAD spatial;")
  }

  if (proxy) {
    DBI::dbExecute(con, "SET http_timeout = 300000;")
    DBI::dbExecute(con, "SET http_retries = 5;")
    DBI::dbExecute(con, "SET http_retry_wait_ms = 2000;")
    DBI::dbExecute(con, "SET http_retry_backoff = 4;")
  }

  DBI::dbExecute(con, "SET s3_endpoint = 's3.opensky-network.org';")
  DBI::dbExecute(con, "SET s3_url_style = 'path';")
  DBI::dbExecute(con, "SET s3_use_ssl = true;")

  username <- Sys.getenv("OSN_USERNAME")
  key      <- Sys.getenv("OSN_KEY")

  if (username == "" || key == "") {
    DBI::dbDisconnect(con, shutdown = TRUE)
    stop("Environment variables OSN_USERNAME and OSN_KEY must be set.")
  }

  DBI::dbExecute(con, sprintf("SET s3_access_key_id = '%s';", username))
  DBI::dbExecute(con, sprintf("SET s3_secret_access_key = '%s';", key))

  con
}

#' Disconnect from OpenSky Network
#'
#' Shuts down the DuckDB connection cleanly.
#'
#' @param con A DBI connection returned by [osn_connect()].
#' @export
osn_disconnect <- function(con) {
  DBI::dbDisconnect(con, shutdown = TRUE)
}
