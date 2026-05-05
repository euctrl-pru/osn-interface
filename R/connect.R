#' Create a DuckDB connection configured for OpenSky Network S3
#'
#' Initialises a DuckDB connection, installs/loads the `httpfs` and `spatial`
#' extensions, and configures S3 access to the OSN bucket using the
#' `OSN_USERNAME` and `OSN_KEY` environment variables.
#'
#' @return A DBI connection object.
#' @export
osn_connect <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())

  DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  DBI::dbExecute(con, "INSTALL spatial; LOAD spatial;")

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
