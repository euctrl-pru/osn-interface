#' Look up airport coordinates by ICAO identifier
#'
#' Reads the bundled airports reference file and returns the coordinates for the
#' requested airport.
#'
#' @param ident ICAO airport code (e.g. `"EHAM"`, `"EGLL"`).
#' @return A named list with elements `lat` and `lon`.
#' @export
osn_airport_coords <- function(ident) {
  path <- system.file("extdata", "airports.csv", package = "osninterface")
  if (path == "") {
    stop("airports.csv not found. Is the osninterface package installed?")
  }

  airports <- utils::read.csv(path, stringsAsFactors = FALSE)
  match    <- airports[airports$ident == ident, , drop = FALSE]

  if (nrow(match) == 0) {
    stop(sprintf("Airport '%s' not found in reference data.", ident))
  }

  list(lat = match$latitude_deg[1], lon = match$longitude_deg[1])
}

#' Fetch state vectors around an airport
#'
#' Convenience wrapper that combines [osn_fetch_day()],
#' [osn_airport_coords()], and [osn_filter_radius()]. The airport bounding box
#' is pushed into the fetch (server-side for the `"osn-historical-trino"`
#' source, so only nearby rows are transferred), then refined with a precise
#' Haversine radius filter.
#'
#' @param ident ICAO airport code (e.g. `"EHAM"`).
#' @param radius_nm Radius in Nautical Miles.
#' @param date Date to fetch. Default: yesterday.
#' @param con A DBI connection from [osn_connect()]. If `NULL`, a new
#'   connection is created automatically.
#' @param downsample_s Optional integer. Keep only state vectors whose Unix
#'   `time` is a multiple of this many seconds (`time %% downsample_s == 0`).
#'   Default `5`. Set to `NULL`, `0`, or `1` to keep every row.
#' @return Filtered lazy `tbl_dbi`.
#' @export
osn_fetch_around_airport <- function(ident, radius_nm,
                                     date = Sys.Date() - 1, con = NULL,
                                     downsample_s = 5) {
  coords <- osn_airport_coords(ident)
  bbox   <- osn_bbox(coords$lat, coords$lon, radius_nm)
  osn_fetch_day(date = date, con = con, downsample_s = downsample_s, bbox = bbox) |>
    osn_filter_radius(coords$lat, coords$lon, radius_nm)
}
