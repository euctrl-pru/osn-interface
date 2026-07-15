# osn-interface

R package for querying OpenSky Network (OSN) state vector data via
DuckDB, reading parquet files directly from the OSN S3-compatible
bucket.

## Project Overview

### Goal

Provide lightweight R functions to lazily query OpenSky Network
historical state vector data without downloading bulk files. The package
connects DuckDB directly to the OSN S3 endpoint
(`s3.opensky-network.org`) using the `httpfs` extension, enabling
predicate pushdown and lazy evaluation on remote parquet files.

### Why DuckDB + S3 (not Trino)

OpenSky also exposes a Trino endpoint (`trino.opensky-network.org`), but
direct S3 access via DuckDB was chosen because: - No Java dependency
(Trino requires RJDBC + JVM) - No query timeouts or concurrency limits
(Trino: 30min timeout, 2 concurrent queries) - Trino uses browser-based
external authentication (hard to automate); S3 uses simple key/secret -
DuckDB provides lazy evaluation with filter and projection pushdown on
remote parquet - Simpler dependency chain: just the `duckdb` R package

### Data Source

- **S3 Endpoint:** `s3.opensky-network.org`
- **Bucket:** `ec-datadump`
- **File pattern:**
  `s3://ec-datadump/YYYY-MM-DD/HH/states_YYYY-MM-DD-HH.parquet` (24
  hourly files per day, each in its own hour subdirectory)
- **Credentials:** Environment variables `OSN_USERNAME` (access key ID)
  and `OSN_KEY` (secret access key)

### Parquet Schema (state vectors)

| Column          | Type        | Description                               |
|-----------------|-------------|-------------------------------------------|
| `time`          | INTEGER     | Unix timestamp of the state vector        |
| `icao24`        | VARCHAR     | ICAO 24-bit transponder address (hex)     |
| `lat`           | DOUBLE      | Latitude (WGS84)                          |
| `lon`           | DOUBLE      | Longitude (WGS84)                         |
| `velocity`      | DOUBLE      | Ground speed (m/s)                        |
| `heading`       | DOUBLE      | True track (degrees clockwise from north) |
| `vertRate`      | DOUBLE      | Vertical rate (m/s)                       |
| `callsign`      | VARCHAR     | Callsign (8 chars)                        |
| `onGround`      | BOOLEAN     | On ground flag                            |
| `alert`         | BOOLEAN     | Alert flag                                |
| `spi`           | BOOLEAN     | Special position indicator                |
| `squawk`        | VARCHAR     | Transponder squawk code                   |
| `baroAltitude`  | DOUBLE      | Barometric altitude (m)                   |
| `geoAltitude`   | DOUBLE      | Geometric altitude (m)                    |
| `lastPosUpdate` | DOUBLE      | Last position update timestamp            |
| `lastContact`   | DOUBLE      | Last contact timestamp                    |
| `serials`       | INTEGER\[\] | Sensor serial numbers                     |

### Airport Reference Data

- File: `reference/airports.csv`
- Lookup key: `ident` column (ICAO code, e.g., `"EHAM"`, `"EGLL"`)
- Coordinates: `latitude_deg`, `longitude_deg`

### Core Functions

1.  **[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)**
    — Create and configure a DuckDB connection with S3/httpfs pointed at
    the OSN bucket. Reads credentials from env vars.

2.  **`osn_fetch_day(date = Sys.Date() - 1, con = NULL)`** — Lazily
    fetch state vectors for a specific day (default: yesterday, D-1).
    Returns a lazy `tbl` (dbplyr) that can be further filtered before
    collection.

3.  **`osn_filter_radius(lazy_tbl, lat, lon, radius_nm)`** — Given a
    lazy table, filter to state vectors within a radius (in Nautical
    Miles) of given coordinates. Uses bounding-box pre-filter +
    Haversine refinement.

4.  **`osn_airport_coords(ident)`** — Look up airport coordinates from
    `reference/airports.csv` by ICAO identifier. Returns a list with
    `lat` and `lon`.

5.  **`osn_fetch_around_airport(ident, radius_nm, date = Sys.Date() - 1, con = NULL)`**
    — Convenience wrapper: fetches a day’s data filtered to a radius
    around a named airport.

## Technical Details

### DuckDB Extensions

``` r

dbExecute(con, "INSTALL httpfs; LOAD httpfs;")   # S3 remote parquet access
dbExecute(con, "INSTALL spatial; LOAD spatial;")  # ST_Distance_Sphere (Haversine)
dbExecute(con, "SET s3_endpoint='s3.opensky-network.org';")
dbExecute(con, "SET s3_url_style='path';")
dbExecute(con, "SET s3_access_key_id=<from OSN_USERNAME>;")
dbExecute(con, "SET s3_secret_access_key=<from OSN_KEY>;")
```

### Coordinate Filtering

- Radius specified in Nautical Miles (NM)
- 1 NM = 1852 m = 1/60 of a degree of latitude
- Uses bounding-box pre-filter (fast, pushed down to parquet row-group
  pruning)
- Then
  `ST_Distance_Sphere(ST_Point(lon, lat), ST_Point(ref_lon, ref_lat))`
  from DuckDB’s `spatial` extension for precise Haversine great-circle
  distance (returns meters)
- Both steps run inside DuckDB’s engine via dbplyr lazy evaluation

### Lazy Evaluation Strategy

- [`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md)
  returns a `dbplyr` lazy table backed by `read_parquet()` on the S3
  glob
- No data is fetched until the user calls `collect()`,
  [`head()`](https://rdrr.io/r/utils/head.html), or similar
- Predicate pushdown: WHERE clauses on parquet columns skip irrelevant
  row groups
- Projection pushdown: only selected columns are transferred

## R Dependencies

- `duckdb` (\>= 1.0.0) — database engine + httpfs extension
- `DBI` — database interface
- `dplyr` — data manipulation
- `dbplyr` — lazy table translation to SQL

## Environment Variables

- `OSN_USERNAME` — OpenSky Network S3 access key ID
- `OSN_KEY` — OpenSky Network S3 secret access key

## Development Notes

- Standard R package structure (DESCRIPTION, NAMESPACE, roxygen2 docs)
- Keep functions minimal — no unnecessary abstractions
- All SQL generation goes through dbplyr where possible; raw SQL only
  when necessary
- Include installation instructions in README.md
