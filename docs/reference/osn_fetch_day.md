# Lazily fetch state vectors for a single day

Returns a lazy `dbplyr` table of one day's state vectors. No data is
transferred until you call
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html),
[`head()`](https://rdrr.io/r/utils/head.html), or similar. The source
recorded on `con` (see
[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md))
selects the backend:

## Usage

``` r
osn_fetch_day(date = Sys.Date() - 1, con = NULL, downsample_s = 5, bbox = NULL)
```

## Arguments

- date:

  Date to fetch. Default: yesterday (`Sys.Date() - 1`).

- con:

  A DBI connection from
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).
  If `NULL`, a new connection is created automatically.

- downsample_s:

  Optional integer. Keep only state vectors whose Unix `time` is a
  multiple of this many seconds (`time %% downsample_s == 0`), reducing
  the update rate. Default `5` (5-second updates), matching pyopensky's
  behaviour. Set to `NULL`, `0`, or `1` to keep every row.

- bbox:

  Optional bounding box (list with `lat_min`, `lat_max`, `lon_min`,
  `lon_max`) to pre-filter server-side. For the `"osn-historical-trino"`
  source this is pushed into the Trino query so only rows inside the box
  are transferred — important for performance, as an unfiltered day is
  very large. Ignored by the `"osn-ec-datadump"` source (which prunes
  via the later
  [`osn_filter_radius()`](https://euctrl-pru.github.io/osn-interface/reference/osn_filter_radius.md)
  parquet pushdown). Usually set indirectly via
  [`osn_fetch_around_airport()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_around_airport.md).

## Value

A lazy `tbl_dbi` (dbplyr table).

## Details

- `"osn-ec-datadump"` — a DuckDB view over the remote parquet files in
  the OSN S3 bucket.

- `"osn-historical-trino"` — the day is queried from the OSN Trino
  endpoint and registered into DuckDB as a lazy table.

Either way the returned object is a lazy `tbl_dbi` with identical
schema.
