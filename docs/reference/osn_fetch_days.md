# Lazily fetch state vectors for a date range

Convenience wrapper around
[`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md)
that spans multiple days.

## Usage

``` r
osn_fetch_days(from, to, con = NULL, downsample_s = 5, bbox = NULL)
```

## Arguments

- from:

  Start date (inclusive).

- to:

  End date (inclusive).

- con:

  A DBI connection from
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).
  If `NULL`, a new connection is created automatically.

- downsample_s:

  Optional integer. Keep only state vectors whose Unix `time` is a
  multiple of this many seconds (`time %% downsample_s == 0`). Default
  `5`. Set to `NULL`, `0`, or `1` to keep every row.

- bbox:

  Optional bounding box (see
  [`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md))
  pushed into the Trino query for the `"osn-historical-trino"` source.

## Value

A lazy `tbl_dbi` (dbplyr table).
