# osninterface

R package for lazily querying [OpenSky Network](https://opensky-network.org/) historical state vector data via DuckDB. Reads parquet files directly from the OSN S3 bucket — no bulk downloads needed.

## How it works

DuckDB's `httpfs` extension connects directly to the OpenSky S3-compatible storage (`s3.opensky-network.org`) and reads parquet files on demand. Queries are lazy: no data is transferred until you call `collect()`. The `spatial` extension provides native Haversine distance (`ST_Distance_Sphere`) for geographic filtering.

## Prerequisites

- **R** >= 4.1.0
- **OpenSky Network account** with S3 data access (typically university-affiliated researchers, governmental organisations, or aviation authorities)

## Installation

```r
# Install from GitHub
# install.packages("remotes")
remotes::install_github("euctrl-pru/osn-interface")
```

Or install from a local clone:

```r
# From the project root directory
devtools::install()
```

### R dependencies

These are installed automatically:

- `duckdb` (>= 1.0.0)
- `DBI`
- `dplyr`
- `dbplyr`

### DuckDB extensions

On first use, `osn_connect()` installs two DuckDB extensions (cached locally after first download):

- `httpfs` — S3/HTTP remote file access
- `spatial` — `ST_Distance_Sphere` for Haversine distance

## Configuration

Set the following environment variables with your OpenSky S3 credentials.

### macOS

Add to `~/.zshrc` (or `~/.bash_profile` if using bash):

```bash
export OSN_USERNAME="your_opensky_username"
export OSN_KEY="your_opensky_secret_key"
```

Then reload your shell: `source ~/.zshrc`

### Windows

Via PowerShell (persistent, user-level):

```powershell
[Environment]::SetEnvironmentVariable("OSN_USERNAME", "your_opensky_username", "User")
[Environment]::SetEnvironmentVariable("OSN_KEY", "your_opensky_secret_key", "User")
```

Or via Settings > System > About > Advanced system settings > Environment Variables.

### R `.Renviron` (cross-platform)

Add to your `~/.Renviron` file (create it if it doesn't exist):

```
OSN_USERNAME=your_opensky_username
OSN_KEY=your_opensky_secret_key
```

Restart R for the changes to take effect. You can find the file location with `Sys.getenv("R_USER")`.

## Quick start

```r
library(osninterface)
library(dplyr)

# Connect to OpenSky S3
con <- osn_connect(proxy = TRUE) # proxy = TRUE on ECTL HP laptop / proxy = FALSE on ECTL Macbook

# Or use the airport lookup shorthand
sv_eham <- osn_fetch_around_airport("EHAM", radius_nm = 40, con = con)

# Only now does data actually transfer
result <- sv_eham |> collect()

# Always disconnect when done
osn_disconnect(con)
```

## Functions

| Function | Description |
|---|---|
| `osn_connect()` | Create a DuckDB connection configured for OSN S3 |
| `osn_disconnect(con)` | Shut down the connection |
| `osn_fetch_day(date, con)` | Lazy table for one day's state vectors (default: D-1) |
| `osn_fetch_days(from, to, con)` | Lazy table spanning a date range |
| `osn_filter_radius(.data, lat, lon, radius_nm)` | Filter to a radius (NM) around coordinates |
| `osn_airport_coords(ident)` | Look up airport lat/lon by ICAO code |
| `osn_fetch_around_airport(ident, radius_nm, date, con)` | Fetch + filter around a named airport |

## Documentation

Full documentation is hosted at <https://euctrl-pru.github.io/osn-interface/>.

To build the documentation site locally:

```r
# Install pkgdown if needed
install.packages("pkgdown")

# Generate roxygen2 docs and build the site
roxygen2::roxygenise()
pkgdown::build_site()
```

The site is built and deployed automatically via GitHub Actions on push to `main`. To enable this, go to your repository Settings > Pages and set the source to **GitHub Actions**.

## Data schema

Each row is a state vector with these columns:

| Column | Type | Description |
|---|---|---|
| `time` | integer | Unix timestamp |
| `icao24` | character | Transponder address (hex) |
| `lat` | double | Latitude (WGS84) |
| `lon` | double | Longitude (WGS84) |
| `velocity` | double | Ground speed (m/s) |
| `heading` | double | True track (degrees) |
| `vertRate` | double | Vertical rate (m/s) |
| `callsign` | character | Callsign |
| `onGround` | logical | On ground flag |
| `baroAltitude` | double | Barometric altitude (m) |
| `geoAltitude` | double | Geometric altitude (m) |
| `squawk` | character | Transponder code |
