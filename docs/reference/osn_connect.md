# Create a DuckDB connection configured for OpenSky Network S3

Initialises a DuckDB connection, installs/loads the `httpfs` and
`spatial` extensions, and configures S3 access to the OSN bucket using
the `OSN_USERNAME` and `OSN_KEY` environment variables.

## Usage

``` r
osn_connect()
```

## Value

A DBI connection object.
