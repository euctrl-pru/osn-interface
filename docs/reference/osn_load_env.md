# Load credentials from a local .env file

Convenience wrapper around
[`base::readRenviron()`](https://rdrr.io/r/base/readRenviron.html) that
loads the credential environment variables (`OSN_USERNAME`, `OSN_KEY`,
`OPENSKY_USERNAME`, `OPENSKY_PASSWORD`, ...) from a local `.env` file
into the current R session. Copy `.env.template` to `.env` and fill in
your values first.

## Usage

``` r
osn_load_env(path = ".env")
```

## Arguments

- path:

  Path to the env file. Default: `".env"` in the working directory.

## Value

Invisibly `TRUE` on success. Errors if the file does not exist.

## Examples

``` r
if (FALSE) { # \dontrun{
osn_load_env()          # loads ./.env
osn_load_env("~/.env")  # loads a specific file
} # }
```
