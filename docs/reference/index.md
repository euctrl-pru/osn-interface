# Package index

## Connection

- [`osn_connect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_connect.md)
  : Create a DuckDB connection configured for OpenSky Network S3
- [`osn_disconnect()`](https://euctrl-pru.github.io/osn-interface/reference/osn_disconnect.md)
  : Disconnect from OpenSky Network

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
