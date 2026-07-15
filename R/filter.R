# Bounding box (in degrees) that encloses a circle of `radius_nm` Nautical Miles
# around (lat, lon). 1 NM = 1/60 degree of latitude; longitude is scaled by
# cos(lat). Returns a list(lat_min, lat_max, lon_min, lon_max) suitable for both
# the DuckDB pre-filter and Trino server-side pushdown.
osn_bbox <- function(lat, lon, radius_nm) {
  dlat <- radius_nm / 60
  dlon <- radius_nm / (60 * cos(lat * pi / 180))
  list(
    lat_min = lat - dlat, lat_max = lat + dlat,
    lon_min = lon - dlon, lon_max = lon + dlon
  )
}

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

  bb      <- osn_bbox(lat, lon, radius_nm)
  lat_min <- bb$lat_min
  lat_max <- bb$lat_max
  lon_min <- bb$lon_min
  lon_max <- bb$lon_max

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
