# Package index

## Connection

- [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)
  : Create a DuckDB connection configured for OpenSky Network S3
- [`osn_source()`](https://euctrl-pru.github.io/osn-interface/reference/osn_source.md)
  : Get the data source recorded on an OSN connection
- [`osn_disconnect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_disconnect.md)
  : Disconnect from OpenSky Network
- [`osn_load_env()`](https://euctrl-pru.github.io/osn-interface/reference/osn_load_env.md)
  : Load credentials from a local .env file

## Fetching data

- [`osn_fetch_day()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_day.md)
  : Lazily fetch state vectors for a single day
- [`osn_fetch_days()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_days.md)
  : Lazily fetch state vectors for a date range

## Spatial filtering

- [`osn_filter_radius()`](https://euctrl-pru.github.io/osn-interface/reference/osn_filter_radius.md)
  : Filter state vectors to a radius around a point

## Airport lookup

- [`osn_airport_coords()`](https://euctrl-pru.github.io/osn-interface/reference/osn_airport_coords.md)
  : Look up airport coordinates by ICAO identifier
- [`osn_fetch_around_airport()`](https://euctrl-pru.github.io/osn-interface/reference/osn_fetch_around_airport.md)
  : Fetch state vectors around an airport

## Historical Trino source

- [`osn_trino_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_trino_connect.md)
  : Open a connection to the OpenSky Network Trino endpoint
