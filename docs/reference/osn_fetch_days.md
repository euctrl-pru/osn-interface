# Lazily fetch state vectors for a date range

Convenience wrapper around
[`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md)
that spans multiple days.

## Usage

``` r
osn_fetch_days(from, to, con = NULL)
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

## Value

A lazy `tbl_dbi` (dbplyr table).
