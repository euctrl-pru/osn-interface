# Fetch state vectors around an airport

Convenience wrapper that combines
[`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md),
[`osn_airport_coords()`](https://euctrl-pru.github.io/osn-interface/reference/osn_airport_coords.md),
and
[`osn_filter_radius()`](https://euctrl-pru.github.io/osn-interface/reference/osn_filter_radius.md).
The airport bounding box is pushed into the fetch (server-side for the
`"osn-historical-trino"` source, so only nearby rows are transferred),
then refined with a precise Haversine radius filter.

## Usage

``` r
osn_fetch_around_airport(
  ident,
  radius_nm,
  date = Sys.Date() - 1,
  con = NULL,
  downsample_s = 5
)
```

## Arguments

- ident:

  ICAO airport code (e.g. `"EHAM"`).

- radius_nm:

  Radius in Nautical Miles.

- date:

  Date to fetch. Default: yesterday.

- con:

  A DBI connection from
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).
  If `NULL`, a new connection is created automatically.

- downsample_s:

  Optional integer. Keep only state vectors whose Unix `time` is a
  multiple of this many seconds (`time %% downsample_s == 0`). Default
  `5`. Set to `NULL`, `0`, or `1` to keep every row.

## Value

Filtered lazy `tbl_dbi`.
