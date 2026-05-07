# Lazily fetch state vectors for a single day

Creates a DuckDB view over the remote parquet files for the given date
and returns a lazy `dbplyr` table. No data is downloaded until you call
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html),
[`head()`](https://rdrr.io/r/utils/head.html), or similar.

## Usage

``` r
osn_fetch_day(date = Sys.Date() - 1, con = NULL)
```

## Arguments

- date:

  Date to fetch. Default: yesterday (`Sys.Date() - 1`).

- con:

  A DBI connection from
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).
  If `NULL`, a new connection is created automatically.

## Value

A lazy `tbl_dbi` (dbplyr table).
