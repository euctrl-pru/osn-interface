# Look up airport coordinates by ICAO identifier

Reads the bundled airports reference file and returns the coordinates
for the requested airport.

## Usage

``` r
osn_airport_coords(ident)
```

## Arguments

- ident:

  ICAO airport code (e.g. `"EHAM"`, `"EGLL"`).

## Value

A named list with elements `lat` and `lon`.
