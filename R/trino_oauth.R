# OSN Trino OAuth2 (external / browser) authentication ------------------------
#
# trino.opensky-network.org gates programmatic access behind an OAuth2 "external
# authentication" flow (the same one the `trino` CLI performs with
# `--external-authentication`). An unauthenticated request returns:
#
#   HTTP 401
#   WWW-Authenticate: Bearer x_redirect_server="https://.../oauth2/token/initiate/<id>",
#                            x_token_server="https://.../oauth2/token/<uuid>"
#
# The client must: (1) open x_redirect_server in a browser for the user to log
# in via OSN SSO, then (2) poll x_token_server until it returns a JWT, and
# (3) send that JWT as `Authorization: Bearer <jwt>` on all subsequent requests.
#
# Tokens are cached on disk (per user config dir) so a browser login is only
# needed when the cached token is missing or expired.

# Parse the `x_redirect_server` / `x_token_server` values out of a Bearer
# WWW-Authenticate challenge header. Returns a list(redirect=, token=) or NULL.
osn_parse_bearer_challenge <- function(headers) {
  # httr lowercases header names; there may be multiple WWW-Authenticate values.
  wa <- unlist(headers[names(headers) == "www-authenticate"], use.names = FALSE)
  bearer <- grep("^Bearer ", wa, value = TRUE)
  if (length(bearer) == 0) return(NULL)
  b <- bearer[1]

  grab <- function(key) {
    m <- regmatches(b, regexec(sprintf('%s="([^"]+)"', key), b))[[1]]
    if (length(m) < 2) NA_character_ else m[2]
  }
  redirect <- grab("x_redirect_server")
  token    <- grab("x_token_server")
  if (is.na(redirect) || is.na(token)) return(NULL)
  list(redirect = redirect, token = token)
}

# Where cached Trino tokens live.
osn_token_cache_path <- function() {
  dir <- tools::R_user_dir("osninterface", which = "cache")
  file.path(dir, "trino_token")
}

osn_read_cached_token <- function() {
  path <- osn_token_cache_path()
  if (!file.exists(path)) return(NULL)
  tok <- tryCatch(readLines(path, warn = FALSE)[1], error = function(e) NULL)
  if (is.null(tok) || !nzchar(tok)) return(NULL)
  if (osn_token_expired(tok)) return(NULL)
  tok
}

osn_write_cached_token <- function(token) {
  path <- osn_token_cache_path()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(token, path)
  # Restrict permissions; the token is a bearer credential.
  try(Sys.chmod(path, mode = "0600"), silent = TRUE)
  invisible(token)
}

# Decode a JWT's `exp` claim and report whether it is expired (with a small
# safety margin). Non-JWT or unparseable tokens are treated as non-expiring
# here (the server will reject them and trigger a fresh flow).
osn_token_expired <- function(token, margin_s = 60) {
  parts <- strsplit(token, ".", fixed = TRUE)[[1]]
  if (length(parts) < 2) return(FALSE)
  payload <- tryCatch({
    b64 <- gsub("-", "+", gsub("_", "/", parts[2]))
    b64 <- paste0(b64, strrep("=", (4 - nchar(b64) %% 4) %% 4))
    rawToChar(jsonlite::base64_dec(b64))
  }, error = function(e) NULL)
  if (is.null(payload)) return(FALSE)
  exp <- tryCatch(jsonlite::fromJSON(payload)$exp, error = function(e) NULL)
  if (is.null(exp) || !is.numeric(exp)) return(FALSE)
  (as.numeric(Sys.time()) + margin_s) >= exp
}

# Perform the interactive OAuth2 flow: trigger a 401 to read the challenge,
# open the browser at x_redirect_server, then poll x_token_server for the JWT.
# Returns the token string. `open_browser` and `interactive_ok` exist mainly for
# testing.
osn_trino_oauth_token <- function(host = osn_trino_host,
                                  timeout_s = 300, poll_interval_s = 2,
                                  open_browser = TRUE) {
  if (!requireNamespace("httr", quietly = TRUE) ||
      !requireNamespace("jsonlite", quietly = TRUE)) {
    stop("OAuth2 Trino auth requires the 'httr' and 'jsonlite' packages.")
  }

  # 1. Unauthenticated request to read the Bearer challenge.
  probe <- httr::POST(paste0(host, "/v1/statement"), body = "SELECT 1", encode = "raw")
  if (httr::status_code(probe) != 401) {
    stop(sprintf("Expected 401 auth challenge from Trino, got %d.", httr::status_code(probe)))
  }
  ch <- osn_parse_bearer_challenge(httr::headers(probe))
  if (is.null(ch)) {
    stop("Trino did not advertise an OAuth2 (Bearer) challenge; cannot start external auth.")
  }

  # 2. Ask the user to authenticate in the browser.
  message("OpenSky Trino requires a browser login. Opening:\n  ", ch$redirect,
          "\nComplete the login in your browser; waiting for authorisation...")
  if (open_browser) try(utils::browseURL(ch$redirect), silent = TRUE)

  # 3. Poll the token server until it returns a token (200 + body) or we time out.
  deadline <- Sys.time() + timeout_s
  repeat {
    resp <- tryCatch(httr::GET(ch$token), error = function(e) NULL)
    if (!is.null(resp) && httr::status_code(resp) == 200) {
      body <- httr::content(resp, as = "text", encoding = "UTF-8")
      token <- osn_extract_token(body)
      if (!is.null(token)) {
        osn_write_cached_token(token)
        message("Trino authorisation received.")
        return(token)
      }
    }
    if (Sys.time() > deadline) {
      stop("Timed out waiting for OpenSky Trino browser authorisation.")
    }
    Sys.sleep(poll_interval_s)
  }
}

# The token server may return the JWT as a bare string or as JSON ({"token":...}).
osn_extract_token <- function(body) {
  body <- trimws(body)
  if (!nzchar(body)) return(NULL)
  if (startsWith(body, "{")) {
    parsed <- tryCatch(jsonlite::fromJSON(body), error = function(e) NULL)
    if (!is.null(parsed)) {
      for (k in c("token", "access_token", "accessToken")) {
        if (!is.null(parsed[[k]]) && nzchar(parsed[[k]])) return(parsed[[k]])
      }
    }
    return(NULL)
  }
  body
}

# Return a valid Trino bearer token: cached if present and unexpired, otherwise
# run the interactive flow. `force` bypasses the cache.
osn_trino_get_token <- function(force = FALSE, open_browser = TRUE) {
  if (!force) {
    cached <- osn_read_cached_token()
    if (!is.null(cached)) return(cached)
  }
  osn_trino_oauth_token(open_browser = open_browser)
}
