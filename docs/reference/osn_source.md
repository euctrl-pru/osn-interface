# Get the data source recorded on an OSN connection

Returns the `source` (`"osn-ec-datadump"` or `"osn-historical-trino"`)
that
[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)
stored on the connection. Defaults to `"osn-ec-datadump"` when the
attribute is absent (e.g. for a connection not created by
[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)).

## Usage

``` r
osn_source(con)
```

## Arguments

- con:

  A DBI connection from
  [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md).

## Value

A character scalar: `"osn-ec-datadump"` or `"osn-historical-trino"`.
