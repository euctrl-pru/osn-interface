# Create a DuckDB connection configured for OpenSky Network S3

Initialises a DuckDB connection, installs/loads the `httpfs` and
`spatial` extensions, and configures S3 access to the OSN bucket using
the `OSN_USERNAME` and `OSN_KEY` environment variables.

## Usage

``` r
osn_connect(
  proxy = FALSE,
  extension_directory = NULL,
  source = c("osn-ec-datadump", "osn-historical-trino")
)
```

## Arguments

- proxy:

  Logical. If `TRUE`, configures DuckDB to route through a corporate
  HTTP proxy. Proxy URL and password are parsed from the `HTTPS_PROXY`
  environment variable (expected format:
  `http://user:password@host:port`). The proxy username is taken from
  the Windows session username. Extensions are force-installed to a
  local directory and additional extensions (`ui`, `h3`) are installed.

- extension_directory:

  Optional. Path to directory containing DuckDB extensions. If
  specified, DuckDB will use local extensions instead of downloading
  them. Can also be set via `DUCKDB_EXTENSION_DIRECTORY` environment
  variable. Useful in corporate environments with restricted internet
  access. If not specified and the environment variable is not set,
  DuckDB will download extensions as needed (current default behavior).

- source:

  Data source to use for subsequent fetches. One of:

  - `"osn-ec-datadump"` (default) — read parquet directly from the OSN
    S3 bucket (`s3.opensky-network.org`) using the `OSN_USERNAME` /
    `OSN_KEY` credentials. This is the original behaviour.

  - `"osn-historical-trino"` — read the same underlying OSN data from
    the OSN historical Trino endpoint (`trino.opensky-network.org`), the
    backend used by the
    [pyopensky](https://github.com/open-aviation/pyopensky) / `traffic`
    Python libraries, authenticated with the `OPENSKY_USERNAME` /
    `OPENSKY_PASSWORD` credentials. Requires the `RPresto` and `httr`
    packages. Both sources return lazy `dbplyr` tables; the fetch
    functions read this choice from the connection. The chosen source is
    stored on the connection (see
    [`osn_source()`](https://euctrl-pru.github.io/osn-interface/reference/osn_source.md))
    so the `osn_fetch_*()` functions know which backend to use without
    an extra argument.

## Value

A DBI connection object with the selected data `source` recorded as an
attribute.

## Examples

``` r
if (FALSE) { # \dontrun{
# Use local extensions (method 1: parameter)
con <- osn_connect(extension_directory = "~/dev/duckdb_ext")

# Use local extensions (method 2: environment variable)
Sys.setenv(DUCKDB_EXTENSION_DIRECTORY = "~/dev/duckdb_ext")
con <- osn_connect()

# Default S3 (ec-datadump) source
con <- osn_connect()

# Secondary historical Trino source
con <- osn_connect(source = "osn-historical-trino")
} # }
```
