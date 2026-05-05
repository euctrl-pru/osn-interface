#' Lazily fetch state vectors for a single day
#'
#' Creates a DuckDB view over the remote parquet files for the given date and
#' returns a lazy `dbplyr` table. No data is downloaded until you call
#' [dplyr::collect()], [head()], or similar.
#'
#' @param date Date to fetch. Default: yesterday (`Sys.Date() - 1`).
#' @param con A DBI connection from [osn_connect()]. If `NULL`, a new
#'   connection is created automatically.
#' @return A lazy `tbl_dbi` (dbplyr table).
#' @export
osn_fetch_day <- function(date = Sys.Date() - 1, con = NULL) {
  if (is.null(con)) con <- osn_connect()

  date_str <- format(as.Date(date), "%Y-%m-%d")
  s3_glob  <- sprintf(
    "s3://ec-datadump/%s/*/states_%s-*.parquet",
    date_str, date_str
  )

  view_name <- sprintf("sv_%s", gsub("-", "", date_str))
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_parquet('%s')",
    view_name, s3_glob
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
#' @return A lazy `tbl_dbi` (dbplyr table).
#' @export
osn_fetch_days <- function(from, to, con = NULL) {
  if (is.null(con)) con <- osn_connect()

  from  <- as.Date(from)
  to    <- as.Date(to)
  dates <- seq(from, to, by = "day")

  globs <- sprintf(
    "'s3://ec-datadump/%s/*/states_%s-*.parquet'",
    format(dates, "%Y-%m-%d"), format(dates, "%Y-%m-%d")
  )
  glob_list <- paste(globs, collapse = ", ")

  view_name <- sprintf("sv_%s_%s", format(from, "%Y%m%d"), format(to, "%Y%m%d"))
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE VIEW %s AS SELECT * FROM read_parquet([%s])",
    view_name, glob_list
  ))

  dplyr::tbl(con, view_name)
}
