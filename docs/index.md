# osninterface

A EUROCONTROL R package (for internal use) for lazily querying [OpenSky
Network](https://opensky-network.org/) historical state vector data via
DuckDB. Reads parquet files directly from the OSN S3 bucket — no bulk
downloads needed.

## How it works

DuckDB’s `httpfs` extension connects directly to the OpenSky
S3-compatible storage (`s3.opensky-network.org`) and reads parquet files
on demand. Queries are lazy: no data is transferred until you call
[`collect()`](https://dplyr.tidyverse.org/reference/compute.html). The
`spatial` extension provides native Haversine distance
(`ST_Distance_Sphere`) for geographic filtering.

## Data sources

The package can read the same OpenSky state-vector data through two
interchangeable sources, selected on the connection with
`osn_connect(source = ...)`:

| `source` | Endpoint | Credentials | Extra deps |
|----|----|----|----|
| `"osn-ec-datadump"` (default) | OSN S3 bucket (`s3.opensky-network.org`) | `OSN_USERNAME`, `OSN_KEY` | — |
| `"osn-historical-trino"` | OSN historical Trino endpoint (`trino.opensky-network.org`, catalog `minio`, schema `osky`) — the backend used by [pyopensky](https://github.com/open-aviation/pyopensky) / `traffic` | OAuth2 browser login (`OPENSKY_USERNAME` used as the Trino user tag) | `RPresto`, `httr`, `jsonlite` |

Both sources return **lazy `dbplyr` tables** with identical schema and
API — the fetch functions read the chosen source from the connection, so
downstream code
([`osn_filter_radius()`](https://euctrl-pru.github.io/osn-interface/reference/osn_filter_radius.md),
[`collect()`](https://dplyr.tidyverse.org/reference/compute.html), …) is
the same either way. The default remains `"osn-ec-datadump"`, so
existing code is unaffected.

The `"osn-historical-trino"` source queries Trino via the native R Trino
client `RPresto`, pulls the result into R, and registers it into DuckDB
as a lazy table. Install its dependencies with
`install.packages(c("RPresto", "httr", "jsonlite"))`.

**Authentication:** OpenSky’s Trino endpoint uses OAuth2 *external*
(browser) authentication — the same flow as
`trino --external-authentication`. The first time you connect in a
session, a browser window opens for you to log in with your OpenSky
account; the resulting bearer token is cached on disk
(`tools::R_user_dir("osninterface", "cache")`) and reused until it
expires, so subsequent connections are non-interactive. Basic
username/password auth is **not** accepted by the OSN Trino server.

**Performance:** an unfiltered day of state vectors is very large, so
always constrain your query.
[`osn_fetch_around_airport()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_around_airport.md)
pushes the airport bounding box into the Trino `WHERE` clause
automatically (partition column `hour` plus `lat`/`lon`), keeping
fetches fast (e.g. EHAM 10 NM for one day ≈ 30 s). The `time %% 5`
downsample is likewise applied server-side.

By default the fetch functions **downsample to one state vector every 5
seconds** (`time %% 5 == 0`), matching pyopensky. Override with the
`downsample_s` argument (e.g. `downsample_s = 1` or `NULL` to keep every
row).

## Prerequisites

- **R** \>= 4.1.0
- **OpenSky Network account** with S3 data access (typically
  university-affiliated researchers, governmental organisations, or
  aviation authorities)

## Installation

``` r

# Install from GitHub
# install.packages("remotes")
remotes::install_github("euctrl-pru/osn-interface")
```

Or install from a local clone:

``` r

# From the project root directory
devtools::install()
```

### R dependencies

These are installed automatically:

- `duckdb` (\>= 1.0.0)
- `DBI`
- `dplyr`
- `dbplyr`

### DuckDB extensions

On first use,
[`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)
installs two DuckDB extensions (cached locally after first download):

- `httpfs` — S3/HTTP remote file access
- `spatial` — `ST_Distance_Sphere` for Haversine distance

#### Using local extensions (corporate environments)

If you’re behind a corporate firewall that blocks extension downloads,
you can use local extensions:

**Method 1: Environment variable** (recommended)

``` r

Sys.setenv(DUCKDB_EXTENSION_DIRECTORY = "~/dev/duckdb_ext")
con <- osn_connect()
```

**Method 2: Function parameter**

``` r

con <- osn_connect(extension_directory = "~/dev/duckdb_ext")
```

This is particularly useful in restricted network environments where
downloading extensions fails.

## Getting started (first use)

A step-by-step walkthrough for setting up the package from scratch.

### 1. Get OpenSky credentials

You need an [OpenSky Network](https://opensky-network.org/) account with
historical-data access (request it at
<https://opensky-network.org/my-opensky/request-data>). Depending on
which source you use:

- **`osn-ec-datadump` (default, S3):** an **S3 access key ID + secret
  key** pair. These look like `k4d8f2...` (≈16 chars) and a longer
  secret (≈32 chars). They go in `OSN_USERNAME` and `OSN_KEY`.
- **`osn-historical-trino` (Trino):** your OpenSky **account username**,
  used only as a tag in `OPENSKY_USERNAME`. You do **not** put a
  password here — the Trino source logs in through your browser
  (OAuth2). See [Data sources](#data-sources).

### 2. Install the package and (optionally) the Trino dependencies

``` r

# install.packages("remotes")
remotes::install_github("euctrl-pru/osn-interface")

# Only needed if you will use source = "osn-historical-trino":
install.packages(c("RPresto", "httr", "jsonlite"))
```

### 3. Create a `.env` file with your credentials

From the project root (or any working directory), copy the template and
fill it in:

``` bash
cp .env.template .env
```

Then edit `.env` so it looks like this (fill in your own values):

``` dotenv
# --- osn-ec-datadump source (default) ---
OSN_USERNAME=your_s3_access_key_id
OSN_KEY=your_s3_secret_access_key

# --- osn-historical-trino source ---
OPENSKY_USERNAME=your_opensky_login   # tag only; auth is via browser
OPENSKY_PASSWORD=                      # leave blank — not used by Trino OAuth2
```

`.env` is git-ignored and must never be committed. You only need to fill
in the credentials for the source(s) you intend to use.

### 4. Fetch some data

``` r

library(osninterface)
library(dplyr)

osn_load_env()            # load credentials from ./.env

con <- osn_connect()      # default source = "osn-ec-datadump"

# One day of traffic within 40 NM of Amsterdam Schiphol (D-1 by default)
sv  <- osn_fetch_around_airport("EHAM", radius_nm = 40, con = con)
df  <- sv |> collect()    # data transfers only now (lazy until collect)

head(df)
osn_disconnect(con)
```

To use the Trino source instead, connect with
`osn_connect(source = "osn-historical-trino")`; a browser window opens
on first use for you to log in (the token is then cached — see
[Authentication](#data-sources)).

> **Tip:** if you prefer not to use a `.env` file, set the same
> variables via `~/.Renviron` or your shell — see
> [Configuration](#configuration) below.

## Configuration

Set the following environment variables with your OpenSky S3
credentials.

### macOS

Add to `~/.zshrc` (or `~/.bash_profile` if using bash):

``` bash
export OSN_USERNAME="your_opensky_username"
export OSN_KEY="your_opensky_secret_key"
```

Then reload your shell: `source ~/.zshrc`

### Windows

Via PowerShell (persistent, user-level):

``` powershell
[Environment]::SetEnvironmentVariable("OSN_USERNAME", "your_opensky_username", "User")
[Environment]::SetEnvironmentVariable("OSN_KEY", "your_opensky_secret_key", "User")
```

Or via Settings \> System \> About \> Advanced system settings \>
Environment Variables.

### R `.Renviron` (cross-platform)

Add to your `~/.Renviron` file (create it if it doesn’t exist):

    OSN_USERNAME=your_opensky_username
    OSN_KEY=your_opensky_secret_key

Restart R for the changes to take effect. You can find the file location
with `Sys.getenv("R_USER")`.

### Project `.env` file

For local development you can keep credentials in a project-level `.env`
file instead of your global environment. Copy the provided template and
fill in your values:

``` bash
cp .env.template .env
# then edit .env
```

`.env` is git-ignored and must never be committed. Load it into an R
session with:

``` r

osn_load_env()   # reads ./.env (wrapper around readRenviron())
```

The template covers both sources: `OSN_USERNAME` / `OSN_KEY` for
`"osn-ec-datadump"` and `OPENSKY_USERNAME` / `OPENSKY_PASSWORD` for
`"osn-historical-trino"`.

## Quick start

``` r

library(osninterface)
library(dplyr)

# (optional) load credentials from a project .env file
osn_load_env()

# Connect to the default S3 (ec-datadump) source
con <- osn_connect(proxy = TRUE) # proxy = TRUE on ECTL HP laptop / proxy = FALSE on ECTL Macbook

# ...or use the historical Trino source instead
# con <- osn_connect(source = "osn-historical-trino")

# Airport lookup shorthand (defaults to 5-second updates)
sv_eham <- osn_fetch_around_airport("EHAM", radius_nm = 40, con = con)

# Keep every state vector instead of downsampling
sv_full <- osn_fetch_around_airport("EHAM", radius_nm = 40, con = con, downsample_s = NULL)

# Only now does data actually transfer
result <- sv_eham |> collect()

# Always disconnect when done
osn_disconnect(con)
```

## Functions

| Function | Description |
|----|----|
| `osn_connect(source = ...)` | Create a connection for the `"osn-ec-datadump"` (default) or `"osn-historical-trino"` source |
| `osn_source(con)` | Report the source recorded on a connection |
| [`osn_trino_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_trino_connect.md) | Open a raw Trino (`RPresto`) connection to the OSN historical endpoint |
| `osn_load_env(path = ".env")` | Load credentials from a local `.env` file |
| `osn_disconnect(con)` | Shut down the connection |
| `osn_fetch_day(date, con, downsample_s = 5)` | Lazy table for one day’s state vectors (default: D-1) |
| `osn_fetch_days(from, to, con, downsample_s = 5)` | Lazy table spanning a date range |
| `osn_filter_radius(.data, lat, lon, radius_nm)` | Filter to a radius (NM) around coordinates |
| `osn_airport_coords(ident)` | Look up airport lat/lon by ICAO code |
| `osn_fetch_around_airport(ident, radius_nm, date, con, downsample_s = 5)` | Fetch + filter around a named airport |

## Function reference with examples

Minimal example for each exported function. All examples assume you have
run
[`library(osninterface)`](https://euctrl-pru.github.io/osn-interface/),
[`library(dplyr)`](https://dplyr.tidyverse.org), and
[`osn_load_env()`](https://euctrl-pru.github.io/osn-interface/reference/osn_load_env.md)
first.

### `osn_load_env()`

Load credentials from a local `.env` file into the R session.

``` r

osn_load_env()             # reads ./.env
osn_load_env("~/secrets/osn.env")  # or a specific path
```

### `osn_connect()`

Open a connection and choose the data source. The source is remembered
on the connection.

``` r

con <- osn_connect()                                  # default: osn-ec-datadump (S3)
con <- osn_connect(source = "osn-historical-trino")   # Trino (opens browser on first use)
con <- osn_connect(proxy = TRUE)                       # behind a corporate proxy
con <- osn_connect(extension_directory = "~/dev/duckdb_ext")  # offline DuckDB extensions
```

### `osn_source()`

Report which source a connection uses.

``` r

con <- osn_connect()
osn_source(con)            # "osn-ec-datadump"
```

### `osn_fetch_day()`

Lazy table for a single day (default: yesterday, D-1).

``` r

con <- osn_connect()
sv  <- osn_fetch_day(date = "2024-06-01", con = con)
sv |> filter(!onGround) |> head(100) |> collect()

# keep every state vector (no 5-second downsample)
sv_full <- osn_fetch_day("2024-06-01", con = con, downsample_s = NULL)
```

### `osn_fetch_days()`

Lazy table spanning an inclusive date range.

``` r

con <- osn_connect()
sv  <- osn_fetch_days(from = "2024-06-01", to = "2024-06-03", con = con)
sv |> summarise(n = n()) |> collect()
```

### `osn_airport_coords()`

Look up an airport’s coordinates by ICAO code.

``` r

osn_airport_coords("EHAM")   # list(lat = 52.31, lon = 4.76)
```

### `osn_filter_radius()`

Filter any lazy table to a radius (in Nautical Miles) around a point.
Combines a fast bounding-box pre-filter with a precise Haversine
distance filter.

``` r

con  <- osn_connect()
lhr  <- osn_airport_coords("EGLL")
near <- osn_fetch_day("2024-06-01", con = con) |>
  osn_filter_radius(lat = lhr$lat, lon = lhr$lon, radius_nm = 30)
near |> collect()
```

### `osn_fetch_around_airport()`

Convenience wrapper: fetch a day and filter to a radius around a named
airport in one call. Pushes the bounding box into the query for speed.

``` r

con <- osn_connect()
sv  <- osn_fetch_around_airport("LFPG", radius_nm = 25,
                                date = "2024-06-01", con = con)
sv |> collect()
```

### `osn_trino_connect()`

Open a *raw* Trino connection (a `RPresto`/DBI connection) — for running
arbitrary SQL against the OSN Trino catalog. Most users do not need
this; use `osn_connect(source = "osn-historical-trino")` instead. Opens
a browser for OAuth2 login on first use.

``` r

tcon <- osn_trino_connect()
DBI::dbGetQuery(tcon, "SELECT count(*) FROM minio.osky.state_vectors_data4
                       WHERE hour = 1717200000")
DBI::dbDisconnect(tcon)
```

### `osn_disconnect()`

Close the connection (and its companion Trino connection, if any).
Always call this when done.

``` r

con <- osn_connect()
# ... work ...
osn_disconnect(con)
```

## Documentation

Full documentation is hosted at
<https://euctrl-pru.github.io/osn-interface/>.

To build the documentation site locally:

``` r

# Install pkgdown if needed
install.packages("pkgdown")

# Generate roxygen2 docs and build the site
roxygen2::roxygenise()
pkgdown::build_site()
```

The site is built and deployed automatically via GitHub Actions on push
to `main`. To enable this, go to your repository Settings \> Pages and
set the source to **GitHub Actions**.

## Data schema

Each row is a state vector with these columns:

| Column         | Type      | Description               |
|----------------|-----------|---------------------------|
| `time`         | integer   | Unix timestamp            |
| `icao24`       | character | Transponder address (hex) |
| `lat`          | double    | Latitude (WGS84)          |
| `lon`          | double    | Longitude (WGS84)         |
| `velocity`     | double    | Ground speed (m/s)        |
| `heading`      | double    | True track (degrees)      |
| `vertRate`     | double    | Vertical rate (m/s)       |
| `callsign`     | character | Callsign                  |
| `onGround`     | logical   | On ground flag            |
| `baroAltitude` | double    | Barometric altitude (m)   |
| `geoAltitude`  | double    | Geometric altitude (m)    |
| `squawk`       | character | Transponder code          |
