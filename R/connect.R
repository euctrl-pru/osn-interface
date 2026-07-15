#' Create a DuckDB connection configured for OpenSky Network S3
#'
#' Initialises a DuckDB connection, installs/loads the `httpfs` and `spatial`
#' extensions, and configures S3 access to the OSN bucket using the
#' `OSN_USERNAME` and `OSN_KEY` environment variables.
#'
#' @param proxy Logical. If `TRUE`, configures DuckDB to route through a
#'   corporate HTTP proxy. Proxy URL and password are parsed from the
#'   `HTTPS_PROXY` environment variable (expected format:
#'   `http://user:password@@host:port`). The proxy username is taken from the
#'   Windows session username. Extensions are force-installed to a local
#'   directory and additional extensions (`ui`, `h3`) are installed.
#' @param extension_directory Optional. Path to directory containing DuckDB
#'   extensions. If specified, DuckDB will use local extensions instead of
#'   downloading them. Can also be set via `DUCKDB_EXTENSION_DIRECTORY`
#'   environment variable. Useful in corporate environments with restricted
#'   internet access. If not specified and the environment variable is not set,
#'   DuckDB will download extensions as needed (current default behavior).
#' @param source Data source to use for subsequent fetches. One of:
#'   * `"osn-ec-datadump"` (default) — read parquet directly from the OSN S3
#'     bucket (`s3.opensky-network.org`) using the `OSN_USERNAME` / `OSN_KEY`
#'     credentials. This is the original behaviour.
#'   * `"osn-historical-trino"` — read the same underlying OSN data from the OSN
#'     historical Trino endpoint (`trino.opensky-network.org`), the backend used
#'     by the [pyopensky](https://github.com/open-aviation/pyopensky) /
#'     `traffic` Python libraries, authenticated with the `OPENSKY_USERNAME` /
#'     `OPENSKY_PASSWORD` credentials. Requires the `RPresto` and `httr`
#'     packages. Both sources return lazy `dbplyr` tables; the fetch functions
#'     read this choice from the connection.
#'   The chosen source is stored on the connection (see [osn_source()]) so the
#'   `osn_fetch_*()` functions know which backend to use without an extra
#'   argument.
#' @return A DBI connection object with the selected data `source` recorded as
#'   an attribute.
#' @examples
#' \dontrun{
#' # Use local extensions (method 1: parameter)
#' con <- osn_connect(extension_directory = "~/dev/duckdb_ext")
#'
#' # Use local extensions (method 2: environment variable)
#' Sys.setenv(DUCKDB_EXTENSION_DIRECTORY = "~/dev/duckdb_ext")
#' con <- osn_connect()
#'
#' # Default S3 (ec-datadump) source
#' con <- osn_connect()
#'
#' # Secondary historical Trino source
#' con <- osn_connect(source = "osn-historical-trino")
#' }
#' @export
osn_connect <- function(proxy = FALSE, extension_directory = NULL,
                        source = c("osn-ec-datadump", "osn-historical-trino")) {
  source <- match.arg(source)
  con <- DBI::dbConnect(duckdb::duckdb())

  # Determine extension directory from parameter or environment variable
  ext_dir <- extension_directory
  if (is.null(ext_dir)) {
    env_ext_dir <- Sys.getenv("DUCKDB_EXTENSION_DIRECTORY", "")
    if (nzchar(env_ext_dir)) {
      ext_dir <- env_ext_dir
    }
  }

  # Set extension directory if determined
  if (!is.null(ext_dir) && nzchar(ext_dir)) {
    if (!dir.exists(ext_dir)) {
      warning(sprintf("Extension directory does not exist: %s", ext_dir))
    } else {
      DBI::dbExecute(con, sprintf("SET extension_directory = '%s';", ext_dir))
    }
  }

  if (proxy) {
    https_proxy <- Sys.getenv("HTTPS_PROXY")
    if (https_proxy == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("HTTPS_PROXY environment variable must be set when proxy = TRUE.")
    }

    parsed <- regmatches(
      https_proxy,
      regexec("^(https?://)(?:([^:]+):([^@]+)@)?(.+)$", https_proxy, perl = TRUE)
    )[[1]]
    if (length(parsed) < 5 || parsed[5] == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("Could not parse HTTPS_PROXY. Expected format: http://[user:pass@]host:port")
    }

    proxy_url      <- paste0(parsed[2], parsed[5])
    proxy_password <- parsed[4]
    proxy_username <- Sys.getenv("USERNAME")

    if (proxy_password == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("HTTPS_PROXY must include credentials (http://user:pass@host:port).")
    }

    ext_dir <- file.path("C:/Users", proxy_username, "dev/duckdb_ext")
    DBI::dbExecute(con, sprintf("SET extension_directory = '%s';", ext_dir))
    DBI::dbExecute(con, sprintf("SET http_proxy = '%s';", proxy_url))
    DBI::dbExecute(con, sprintf("SET http_proxy_username = '%s';", proxy_username))
    DBI::dbExecute(con, sprintf("SET http_proxy_password = '%s';", proxy_password))

    DBI::dbExecute(con, "FORCE INSTALL httpfs; LOAD httpfs;")
    DBI::dbExecute(con, "FORCE INSTALL spatial; LOAD spatial;")

    extensions <- DBI::dbGetQuery(
      con, "SELECT extension_name, installed, description FROM duckdb_extensions();"
    )
    message("Installed DuckDB extensions:")
    print(extensions)
  } else {
    # Try loading extensions first (works if already installed locally)
    # Falls back to INSTALL if LOAD fails
    tryCatch({
      DBI::dbExecute(con, "LOAD httpfs;")
      DBI::dbExecute(con, "LOAD spatial;")
    }, error = function(e) {
      DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
      DBI::dbExecute(con, "INSTALL spatial; LOAD spatial;")
    })
  }

  if (proxy) {
    DBI::dbExecute(con, "SET http_timeout = 300000;")
    DBI::dbExecute(con, "SET http_retries = 5;")
    DBI::dbExecute(con, "SET http_retry_wait_ms = 2000;")
    DBI::dbExecute(con, "SET http_retry_backoff = 4;")
  }

  if (source == "osn-historical-trino") {
    # The historical-trino source reaches the OSN Trino endpoint (not S3). The DuckDB
    # connection here is used only as a local engine to register Trino results
    # and run spatial filtering, so no S3 credentials are configured. Open the
    # Trino connection eagerly so auth/dependency errors surface at connect
    # time; it is stored on the DuckDB connection for the fetch functions.
    tcon <- tryCatch(
      osn_trino_connect(),
      error = function(e) {
        DBI::dbDisconnect(con, shutdown = TRUE)
        stop(conditionMessage(e), call. = FALSE)
      }
    )
    attr(con, "osn_trino_con") <- tcon
  } else {
    # The s3 source reads OSN parquet directly via DuckDB's httpfs/S3 client.
    DBI::dbExecute(con, "SET s3_endpoint = 's3.opensky-network.org';")
    DBI::dbExecute(con, "SET s3_url_style = 'path';")
    DBI::dbExecute(con, "SET s3_use_ssl = true;")

    username <- Sys.getenv("OSN_USERNAME")
    key      <- Sys.getenv("OSN_KEY")
    if (username == "" || key == "") {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop("Environment variables OSN_USERNAME and OSN_KEY must be set.")
    }

    DBI::dbExecute(con, sprintf("SET s3_access_key_id = '%s';", username))
    DBI::dbExecute(con, sprintf("SET s3_secret_access_key = '%s';", key))
  }

  # Record the chosen source on the connection so osn_fetch_*() can read it.
  attr(con, "osn_source") <- source

  con
}

#' Get the data source recorded on an OSN connection
#'
#' Returns the `source` (`"osn-ec-datadump"` or `"osn-historical-trino"`) that
#' [osn_connect()] stored on the connection. Defaults to `"osn-ec-datadump"`
#' when the attribute is absent (e.g. for a connection not created by
#' [osn_connect()]).
#'
#' @param con A DBI connection from [osn_connect()].
#' @return A character scalar: `"osn-ec-datadump"` or `"osn-historical-trino"`.
#' @export
osn_source <- function(con) {
  src <- attr(con, "osn_source", exact = TRUE)
  if (is.null(src)) "osn-ec-datadump" else src
}

#' Load credentials from a local .env file
#'
#' Convenience wrapper around [base::readRenviron()] that loads the credential
#' environment variables (`OSN_USERNAME`, `OSN_KEY`, `OPENSKY_USERNAME`,
#' `OPENSKY_PASSWORD`, ...) from a local `.env` file into the current R session.
#' Copy `.env.template` to `.env` and fill in your values first.
#'
#' @param path Path to the env file. Default: `".env"` in the working directory.
#' @return Invisibly `TRUE` on success. Errors if the file does not exist.
#' @examples
#' \dontrun{
#' osn_load_env()          # loads ./.env
#' osn_load_env("~/.env")  # loads a specific file
#' }
#' @export
osn_load_env <- function(path = ".env") {
  if (!file.exists(path)) {
    stop(sprintf("Env file not found: %s (copy .env.template to .env).", path))
  }
  readRenviron(path)
  invisible(TRUE)
}

#' Disconnect from OpenSky Network
#'
#' Shuts down the DuckDB connection cleanly. If a companion Trino connection was
#' opened for the `"osn-historical-trino"` source, it is closed too.
#'
#' @param con A DBI connection returned by [osn_connect()].
#' @export
osn_disconnect <- function(con) {
  tcon <- attr(con, "osn_trino_con", exact = TRUE)
  if (!is.null(tcon)) {
    try(DBI::dbDisconnect(tcon), silent = TRUE)
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
}
