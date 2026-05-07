# Fetch state vectors around an airport

Convenience wrapper that combines
[`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md),
[`osn_airport_coords()`](https://euctrl-pru.github.io/osn-interface/reference/osn_airport_coords.md),
and
[`osn_filter_radius()`](https://euctrl-pru.github.io/osn-interface/reference/osn_filter_radius.md).

## Usage

``` r
osn_fetch_around_airport(ident, radius_nm, date = Sys.Date() - 1, con = NULL)
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

## Value

Filtered lazy `tbl_dbi`.
