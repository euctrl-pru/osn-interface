# Filter state vectors to a radius around a point

Applies a fast bounding-box pre-filter (pushed down to parquet row-group
pruning) followed by a precise Haversine great-circle distance filter
using DuckDB's `ST_Distance_Sphere()`.

## Usage

``` r
osn_filter_radius(.data, lat, lon, radius_nm)
```

## Arguments

- .data:

  A lazy `tbl_dbi` with `lat` and `lon` columns (e.g. from
  [`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md)).

- lat:

  Centre latitude (decimal degrees, WGS84).

- lon:

  Centre longitude (decimal degrees, WGS84).

- radius_nm:

  Radius in Nautical Miles.

## Value

Filtered lazy `tbl_dbi`.
