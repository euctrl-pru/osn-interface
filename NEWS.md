# osninterface 0.2.0

## New Features

* **Second data source.** `osn_connect()` gains a `source` argument selecting the
  backend, stored on the connection and read by all `osn_fetch_*()` functions:
    * `"osn-ec-datadump"` (default) — the original path: DuckDB reads parquet
      directly from the OSN S3 bucket (`OSN_USERNAME` / `OSN_KEY`).
    * `"osn-historical-trino"` — the OSN historical Trino endpoint
      (`trino.opensky-network.org`, catalog `minio`, schema `osky`), the backend
      used by the `pyopensky` / `traffic` Python libraries. Results are pulled
      into R and registered into DuckDB, so both sources return identical lazy
      `dbplyr` tables and all downstream code is unchanged.

* **Trino OAuth2 authentication.** The Trino source authenticates via OpenSky's
  OAuth2 *external* (browser) flow — the same as `trino --external-authentication`.
  A browser login is required on first use per token; the bearer token is cached
  on disk and reused until it expires. New exported helper `osn_trino_connect()`
  opens a raw Trino connection.

* **Temporal downsampling.** `osn_fetch_day()`, `osn_fetch_days()` and
  `osn_fetch_around_airport()` gain a `downsample_s` argument (default `5`)
  keeping only state vectors where `time %% downsample_s == 0` (e.g. one update
  every 5 seconds), matching `pyopensky`. Set to `NULL`, `0` or `1` to keep every
  row. Applied server-side for both sources.

* **Bounding-box pushdown.** `osn_fetch_around_airport()` pushes the airport
  bounding box into the query (server-side for the Trino source, alongside the
  required `hour` partition filter), so only nearby rows are transferred before
  the precise Haversine radius refinement.

* New helpers: `osn_source()` (report a connection's source) and `osn_load_env()`
  (load credentials from a local `.env` file). A `.env.template` documents the
  credentials for both sources.

# osninterface 0.1.1

## New Features

* `osn_connect()` now supports specifying a local extension directory via the 
  `extension_directory` parameter or `DUCKDB_EXTENSION_DIRECTORY` environment 
  variable. This allows using local DuckDB extensions instead of downloading them,
  which is particularly useful in corporate environments with restricted internet 
  access (#XX).

* Extension loading now tries `LOAD` before `INSTALL` in non-proxy mode, 
  automatically using local extensions if available and falling back to download 
  only if needed.

## Bug Fixes

* Fixed issue where `osn_connect()` would fail in corporate environments due to 
  blocked extension downloads, even when extensions existed locally.

# osninterface 0.1.0

* Initial release
