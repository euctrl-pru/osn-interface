# Open a connection to the OpenSky Network Trino endpoint

Connects to `trino.opensky-network.org` (catalog `minio`, schema `osky`)
using the native R Trino client `RPresto`. OpenSky's Trino endpoint uses
OAuth2 external authentication (the same browser-based flow as
`trino --external-authentication`): on first use a browser window opens
for you to log in with your OpenSky account; the resulting bearer token
is cached on disk and reused until it expires. This is the backend used
by the `"osn-historical-trino"` source (see
[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)).

## Usage

``` r
osn_trino_connect(force_login = FALSE)
```

## Arguments

- force_login:

  Logical. If `TRUE`, ignore any cached token and force a fresh browser
  login.

## Value

A `PrestoConnection` (DBI connection) to the OSN Trino server.

## Details

The `OPENSKY_USERNAME` environment variable is used as the Trino user
tag (`X-Trino-User`); the actual authentication happens via the browser
login, not `OPENSKY_PASSWORD`.

Requires the `RPresto`, `httr` and `jsonlite` packages (in Suggests);
install them with `install.packages(c("RPresto", "httr", "jsonlite"))`
if missing.
