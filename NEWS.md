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
