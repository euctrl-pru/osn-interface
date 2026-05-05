#' Filter state vectors to a radius around a point
#'
#' Applies a fast bounding-box pre-filter (pushed down to parquet row-group
#' pruning) followed by a precise Haversine great-circle distance filter using
#' DuckDB's `ST_Distance_Sphere()`.
#'
#' @param .data A lazy `tbl_dbi` with `lat` and `lon` columns (e.g. from
#'   [osn_fetch_day()]).
#' @param lat Centre latitude (decimal degrees, WGS84).
#' @param lon Centre longitude (decimal degrees, WGS84).
#' @param radius_nm Radius in Nautical Miles.
#' @return Filtered lazy `tbl_dbi`.
#' @export
osn_filter_radius <- function(.data, lat, lon, radius_nm) {
  radius_m <- radius_nm * 1852

  # Bounding box: 1 NM = 1/60 degree latitude

  dlat <- radius_nm / 60
  dlon <- radius_nm / (60 * cos(lat * pi / 180))

  lat_min <- lat - dlat
  lat_max <- lat + dlat
  lon_min <- lon - dlon
  lon_max <- lon + dlon

  haversine_sql <- sprintf(
    "ST_Distance_Sphere(ST_Point(lon, lat), ST_Point(%f, %f)) <= %f",
    lon, lat, radius_m
  )

  .data |>
    dplyr::filter(
      lat >= !!lat_min, lat <= !!lat_max,
      lon >= !!lon_min, lon <= !!lon_max
    ) |>
    dplyr::filter(dbplyr::sql(haversine_sql))
}
