#' Build an Elasticsearch query for CVR annual reports
#'
#' Constructs the query body used by [cvr_search()] to look up published
#' annual reports (offentliggoerelser) in Erhvervsstyrelsens distribution
#' service. Companies are matched by CVR number and accounting-period end
#' date. The function is pure: it only builds a nested list and performs no
#' network calls.
#'
#' The full pipeline is:
#'
#' ```r
#' cvr_query(cvr, from, to) |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits() |>
#'   cvr_download("data/pdf")
#' ```
#'
#' @param cvr A character or numeric vector of CVR numbers (8 digits each).
#'   At most 1000 per query -- split larger sets into batches.
#' @param enddate_from,enddate_to Accounting-period end-date range as
#'   `"YYYY-MM-DD"` strings or `Date`s. Only reports whose period ends within
#'   the range (inclusive) are matched.
#' @param size Maximum number of hits the API should return. Default `2999`.
#'
#' @return A nested list ready to be serialised as the JSON request body.
#'
#' @examples
#' query <- cvr_query("12345678", "2024-01-01", "2024-12-31")
#' str(query, max.level = 3)
#'
#' @seealso [cvr_search()], [cvr_hits()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_abort
#' @export
cvr_query <- function(cvr, enddate_from, enddate_to, size = 2999) {
  cvr <- as.character(cvr)
  bad <- cvr[!grepl("^\\d{8}$", cvr)]
  if (length(bad) > 0)
    cli::cli_abort(c(
      "All CVR numbers must be exactly 8 digits.",
      "x" = "{cli::qty(length(bad))}Invalid value{?s}: {.val {utils::head(bad, 5)}}."
    ))
  if (length(cvr) > 1000)
    cli::cli_abort(c(
      "Too many CVR numbers ({length(cvr)}); the API allows at most 1000 per query.",
      "i" = "Split the CVR numbers into batches and combine the results."
    ))

  from <- .parse_date(enddate_from, "enddate_from")
  to   <- .parse_date(enddate_to, "enddate_to")
  if (from > to)
    cli::cli_abort("{.arg enddate_from} must not be later than {.arg enddate_to}.")

  list(
    query = list(
      bool = list(
        must = list(
          # I() keeps a length-1 cvr serialised as a JSON array, as required
          # by the Elasticsearch terms query
          list(terms = list(cvrNummer = I(cvr))),
          list(term = list("dokumenter.dokumentType" = "aarsrapport")),
          list(range = list("regnskab.regnskabsperiode.slutDato" = list(
            gte = sprintf("%sT00:00:00.000Z", from),
            lte = sprintf("%sT23:59:59.999Z", to)
          )))
        )
      )
    ),
    size = size
  )
}

#' Send a query to the CVR distribution service
#'
#' Posts a query built with [cvr_query()] to Erhvervsstyrelsens distribution
#' service and returns the parsed JSON response. Pass the result to
#' [cvr_hits()] to extract the hits as a tibble.
#'
#' @param query A query list, typically from [cvr_query()].
#' @param contact A non-empty string identifying you to the API (sent as the
#'   `User-Agent` header). Erhvervsstyrelsen requires requests to identify
#'   the sender; use an email address.
#' @param scroll Controls how results are fetched. `FALSE` (default): one
#'   request, at most `query$size` hits. `TRUE`: use the Elasticsearch scroll
#'   API to fetch *all* matching hits in batches of 500 (`query$size` is
#'   ignored). A number: like `TRUE` but with that batch size.
#' @param url The endpoint to post to. Defaults to the offentliggoerelser
#'   search endpoint.
#'
#' @return The parsed JSON response as a nested list; with `scroll`, the
#'   batches are combined into one response of the same shape. Without
#'   `scroll`, a warning is issued if the response holds as many hits as the
#'   query's `size` allows, since the result may then be truncated.
#'
#' @examples
#' \dontrun{
#' response <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com")
#'
#' # Large pulls: fetch every matching hit in batches
#' response <- cvr_query(many_cvrs, "2015-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com", scroll = TRUE)
#' }
#'
#' @seealso [cvr_query()], [cvr_hits()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_abort cli_alert_success cli_warn cli_progress_bar cli_progress_update cli_progress_done
#' @export
cvr_search <- function(query, contact, scroll = FALSE,
                       url = "http://distribution.virk.dk/offentliggoerelser/_search") {
  for (pkg in c("curl", "jsonlite"))
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required to use {.fn cvr_search}.")

  if (missing(contact) || is.null(contact) || !nzchar(trimws(contact)))
    cli::cli_abort(c(
      "{.arg contact} must be a non-empty string.",
      "i" = "Erhvervsstyrelsen requires requests to identify the sender; use an email address."
    ))

  if (!isFALSE(scroll) && !isTRUE(scroll) &&
      !(is.numeric(scroll) && length(scroll) == 1 && scroll >= 1))
    cli::cli_abort("{.arg scroll} must be `TRUE`, `FALSE`, or a single batch size >= 1.")

  if (isFALSE(scroll)) {
    parsed <- .cvr_post(url, .cvr_json(query), contact)

    n_hits <- length(parsed$hits$hits)
    cli::cli_alert_success("CVR API request succeeded (HTTP 200, {n_hits} hit{?s}).")
    if (!is.null(query$size) && n_hits >= query$size)
      cli::cli_warn(c(
        "The response holds {n_hits} hits -- as many as the query {.arg size} allows.",
        "i" = "The result may be truncated. Use {.code scroll = TRUE} to fetch all hits."
      ))
    return(parsed)
  }

  # Scroll mode: fetch all hits in batches. The scroll context is kept alive
  # for 5 minutes between calls; continuation requests go to /_search/scroll
  # at the root of the host.
  query$size <- if (isTRUE(scroll)) 500L else as.integer(scroll)

  parsed <- .cvr_post(paste0(url, "?scroll=5m"), .cvr_json(query), contact)
  scroll_id <- parsed[["_scroll_id"]]
  if (is.null(scroll_id))
    cli::cli_abort("The response contains no scroll id -- the endpoint may not support scrolling.")

  all_hits <- parsed$hits$hits
  batch <- all_hits
  n_batches <- 1L
  cli::cli_progress_bar("Scrolling CVR hits", total = NA)
  while (length(batch) > 0) {
    cli::cli_progress_update(status = paste0(length(all_hits), " hits"))
    Sys.sleep(1)
    nxt <- .cvr_post(
      paste0(.scroll_url(url), "?scroll=5m&scroll_id=",
             utils::URLencode(scroll_id, reserved = TRUE)),
      "", contact
    )
    if (!is.null(nxt[["_scroll_id"]])) scroll_id <- nxt[["_scroll_id"]]
    batch <- nxt$hits$hits
    all_hits <- c(all_hits, batch)
    n_batches <- n_batches + 1L
  }
  cli::cli_progress_done()

  parsed$hits$hits <- all_hits
  cli::cli_alert_success(
    "CVR API scroll completed: {length(all_hits)} hit{?s} in {n_batches} request{?s}."
  )
  parsed
}

#' Extract CVR search hits as a tibble
#'
#' Flattens the hits in a response from [cvr_search()] into a tibble with one
#' row per document. Nested field names are reduced to their last component
#' and lowercased (e.g. `dokumenter.dokumentUrl` becomes `dokumenturl`).
#' Fields with several values per hit (typically multiple documents) become
#' multiple rows; single-valued fields are recycled across them.
#'
#' @param response A parsed response list from [cvr_search()].
#'
#' @return A tibble with one row per document. Warns if the `cvrnummer` or
#'   `dokumenturl` columns needed by [cvr_download()] are missing.
#'
#' @examples
#' \dontrun{
#' hits <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits()
#' }
#'
#' @seealso [cvr_query()], [cvr_search()], [cvr_download()]
#' @family cvr
#'
#' @importFrom cli cli_alert_info cli_warn
#' @importFrom dplyr bind_rows
#' @importFrom tibble as_tibble tibble
#' @export
cvr_hits <- function(response) {
  hits <- response$hits$hits
  if (length(hits) == 0) {
    cli::cli_warn("The response contains no hits.")
    return(tibble::tibble())
  }

  rows <- lapply(hits, function(h) {
    v  <- unlist(h[["_source"]])
    nm <- tolower(sub(".*\\.", "", names(v)))
    vals <- split(unname(v), factor(nm, levels = unique(nm)))
    n <- max(lengths(vals))
    vals <- lapply(vals, function(x) {
      if (length(x) == 1) rep(x, n) else c(x, rep(NA, n - length(x)))
    })
    tibble::as_tibble(vals)
  })
  out <- dplyr::bind_rows(rows)

  missing_cols <- setdiff(c("cvrnummer", "dokumenturl"), names(out))
  if (length(missing_cols) > 0)
    cli::cli_warn(
      "{cli::qty(length(missing_cols))}Missing column{?s} required by {.fn cvr_download}: {.val {missing_cols}}."
    )

  cli::cli_alert_info("Extracted {nrow(out)} document row{?s} from {length(hits)} hit{?s}.")
  out
}

#' Download CVR documents
#'
#' Downloads the documents listed in a tibble from [cvr_hits()], one file per
#' row, named by CVR number (repeated CVR numbers get a `_2`, `_3`, ...
#' suffix). A delay between requests keeps the load on the API polite.
#'
#' Each company-year typically lists several files (PDF, XML/XBRL, sometimes
#' XHTML), so filter the hits tibble before downloading if you only need one
#' format -- e.g. `dplyr::filter(hits, dokumentmimetype == "application/pdf")`.
#'
#' @param hits A tibble with `cvrnummer` and `dokumenturl` columns, typically
#'   from [cvr_hits()].
#' @param path Directory to download into. Created automatically if it does
#'   not exist.
#' @param sleep Seconds to wait between downloads. Must be at least 1; the
#'   default of 3 matches the API's expectations for bulk retrieval.
#' @param overwrite If `FALSE` (default), the function aborts when any of the
#'   files it would write already exist. Set to `TRUE` to replace them.
#'
#' @return Invisibly, a character vector of paths to the downloaded files
#'   (failed downloads are not included).
#'
#' @examples
#' \dontrun{
#' cvr_query("12345678", "2024-01-01", "2024-12-31") |>
#'   cvr_search(contact = "you@example.com") |>
#'   cvr_hits() |>
#'   cvr_download("data/pdf")
#' }
#'
#' @seealso [cvr_query()], [cvr_search()], [cvr_hits()],
#'   [accounts_pdf_to_txt()] for the next step of the workflow.
#' @family cvr
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_alert_warning cli_progress_bar cli_progress_update cli_progress_done
#' @export
cvr_download <- function(hits, path, sleep = 3, overwrite = FALSE) {
  if (!requireNamespace("curl", quietly = TRUE))
    cli::cli_abort("Package {.pkg curl} is required to use {.fn cvr_download}.")

  missing_cols <- setdiff(c("cvrnummer", "dokumenturl"), names(hits))
  if (length(missing_cols) > 0)
    cli::cli_abort(
      "{cli::qty(length(missing_cols))}Missing required column{?s}: {.val {missing_cols}}."
    )
  if (nrow(hits) == 0)
    cli::cli_abort("{.arg hits} is empty -- there are no documents to download.")
  if (sleep < 1)
    cli::cli_abort("{.arg sleep} must be at least 1 second to keep the load on the API polite.")

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # File names: cvr number + extension from the url (query strings stripped);
  # repeated cvr numbers get a _2, _3, ... suffix
  ext <- tools::file_ext(sub("[?#].*$", "", hits$dokumenturl))
  dot_ext <- ifelse(nzchar(ext), paste0(".", ext), "")
  occurrence <- stats::ave(seq_along(hits$cvrnummer), hits$cvrnummer, FUN = seq_along)
  suffix <- ifelse(occurrence > 1, paste0("_", occurrence), "")
  filenames <- paste0(hits$cvrnummer, suffix, dot_ext)
  out_paths <- file.path(path, filenames)

  if (!overwrite) {
    existing <- out_paths[file.exists(out_paths)]
    if (length(existing) > 0) {
      shown <- utils::head(basename(existing), 10)
      if (length(existing) > 10)
        shown <- c(shown, cli::format_inline("... and {length(existing) - 10} more"))
      cli::cli_abort(c(
        "Would overwrite {length(existing)} existing file{?s} in {.path {path}}: {shown}.",
        "i" = "Set {.code overwrite = TRUE} to replace existing files."
      ))
    }
  }

  n <- nrow(hits)
  path_lnk <- .path_link(path)
  cli::cli_alert_info(
    "Downloading {n} document{?s} to '{path_lnk}' with {sleep}s between requests..."
  )

  t0 <- Sys.time()
  ok <- logical(n)
  cli::cli_progress_bar("Downloading documents", total = n)
  for (i in seq_len(n)) {
    cli::cli_progress_update(status = filenames[[i]])
    ok[[i]] <- tryCatch({
      curl::curl_download(hits$dokumenturl[[i]], out_paths[[i]], quiet = TRUE)
      TRUE
    }, error = function(e) {
      cli::cli_alert_warning(
        "{filenames[[i]]}: download failed ({conditionMessage(e)}) -- skipped."
      )
      FALSE
    })
    if (i < n) Sys.sleep(sleep)
  }
  cli::cli_progress_done()

  cli::cli_alert_success(
    "Downloaded {sum(ok)} of {n} document{?s} to '{path_lnk}' in {format_elapsed(Sys.time() - t0)}."
  )

  invisible(out_paths[ok])
}

# Parse a single date given as "YYYY-MM-DD" or Date; abort with the argument
# name on anything else (including NULL and NA).
.parse_date <- function(x, arg) {
  d <- tryCatch(suppressWarnings(as.Date(x)), error = function(e) as.Date(NA))
  if (length(d) != 1 || is.na(d))
    cli::cli_abort("{.arg {arg}} must be a single valid date in 'YYYY-MM-DD' format.")
  d
}

.cvr_json <- function(query) {
  as.character(jsonlite::toJSON(query, auto_unbox = TRUE))
}

# POST `body` to `url` with the contact as User-Agent and return the parsed
# JSON response; abort on any non-200 status.
.cvr_post <- function(url, body, contact) {
  h <- curl::new_handle()
  curl::handle_setheaders(h,
    "Content-Type" = "application/json",
    "User-Agent"   = contact
  )
  curl::handle_setopt(h, postfields = body)

  resp <- curl::curl_fetch_memory(url, handle = h)
  if (resp$status_code != 200)
    cli::cli_abort("The CVR API request failed with HTTP status {resp$status_code}.")

  jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
}

# Scroll continuations go to /_search/scroll at the root of the host, not
# under the index path.
.scroll_url <- function(url) {
  paste0(sub("^(https?://[^/]+).*$", "\\1", url), "/_search/scroll")
}
