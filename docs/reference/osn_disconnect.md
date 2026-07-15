# Disconnect from OpenSky Network

Shuts down the DuckDB connection cleanly. If a companion Trino
connection was opened for the `"osn-historical-trino"` source, it is
closed too.

## Usage

``` r
osn_disconnect(con)
```

## Arguments

- con:

  A DBI connection returned by
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).
