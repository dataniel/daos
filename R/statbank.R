# Client for the Greenland Statbank (bank.stat.gl), a PXWeb instance.
# GET requests browse the table tree and fetch metadata; data is fetched
# with a POST carrying a JSON query and parsed from json-stat2.

.sb_base  <- "https://bank.stat.gl/api/v1"
.sb_cache <- new.env(parent = emptyenv())

#' List one level of the Greenland Statbank table tree
#'
#' Fetches the nodes directly under a path in the statbank's table tree.
#' The root holds the subject areas (population, labour market, prices,
#' and so on); each subject holds sub-folders and tables.
#'
#' @param path Path within the tree, e.g. `""` (the root), `"BE"`, or
#'   `"BE/BE01"`. Use the `id` values from the previous level to drill
#'   down.
#' @param lang Language of titles and labels: `"da"` (default), `"en"`,
#'   or `"kl"`.
#'
#' @return A tibble with columns `id`, `type` (`"l"` for folder, `"t"`
#'   for table), `text`, and `updated` (tables only, `NA` for folders).
#'
#' @examples
#' \dontrun{
#' statbank_nodes()          # subject areas
#' statbank_nodes("BE")      # folders under population
#' statbank_nodes("BE/BE01") # tables and folders under BE01
#' }
#'
#' @seealso [daos::statbank_tables()], [daos::statbank_meta()], [daos::statbank_get()]
#'
#' @references Greenland Statbank, <https://bank.stat.gl>.
#'
#' @importFrom cli cli_abort
#' @importFrom tibble as_tibble
#' @export
statbank_nodes <- function(path = "", lang = "da") {
  .sb_check_available()
  x <- .sb_fetch(path, lang)
  x$text <- .sb_strip_html(x$text)
  if (is.null(x$updated)) x$updated <- NA_character_
  tibble::as_tibble(x[, c("id", "type", "text", "updated")])
}

#' List every table in the Greenland Statbank
#'
#' Walks the whole table tree once and returns all tables with their
#' paths and titles. The walk takes a number of small requests (one per
#' folder), so the result is cached for the rest of the session; pass
#' `refresh = TRUE` to fetch it again.
#'
#' @inheritParams statbank_nodes
#' @param refresh If `TRUE`, ignore the session cache and walk the tree
#'   again. Default `FALSE`.
#'
#' @return A tibble with columns `id`, `title`, `path` (the folder the
#'   table sits in), and `updated`.
#'
#' @examples
#' \dontrun{
#' tables <- statbank_tables()
#' }
#'
#' @seealso [daos::statbank_search()], [daos::statbank_meta()]
#'
#' @importFrom cli cli_abort cli_progress_bar cli_progress_update cli_progress_done cli_alert_success
#' @importFrom dplyr bind_rows
#' @export
statbank_tables <- function(lang = "da", refresh = FALSE) {
  .sb_check_available()

  cache_key <- paste0("tables_", lang)
  if (!refresh && !is.null(.sb_cache[[cache_key]])) {
    return(.sb_cache[[cache_key]])
  }

  queue  <- ""
  tables <- list()
  cli::cli_progress_bar("Walking the statbank table tree", total = NA)
  while (length(queue) > 0) {
    path  <- queue[[1]]
    queue <- queue[-1]
    cli::cli_progress_update(status = if (nzchar(path)) path else "root")
    nodes <- statbank_nodes(path, lang)
    children <- nodes$id[nodes$type == "l"]
    if (length(children) > 0) {
      queue <- c(queue, if (nzchar(path)) paste(path, children, sep = "/") else children)
    }
    found <- nodes[nodes$type == "t", ]
    if (nrow(found) > 0) {
      tables[[length(tables) + 1]] <- tibble::tibble(
        id      = found$id,
        title   = found$text,
        path    = path,
        updated = found$updated
      )
    }
  }
  cli::cli_progress_done()

  out <- dplyr::bind_rows(tables)
  .sb_cache[[cache_key]] <- out
  cli::cli_alert_success("Found {nrow(out)} table{?s}.")
  out
}

#' Search Greenland Statbank tables by title
#'
#' Filters the full table list (see [daos::statbank_tables()]) on a search
#' string, matched case-insensitively against titles and table ids. The
#' first call walks the table tree; later calls use the session cache.
#'
#' @param text Search string, interpreted as a regular expression.
#' @inheritParams statbank_tables
#'
#' @return A tibble with the matching rows from [daos::statbank_tables()].
#'
#' @examples
#' \dontrun{
#' statbank_search("befolkning")
#' statbank_search("ledighed")
#' }
#'
#' @seealso [daos::statbank_tables()], [daos::statbank_meta()]
#'
#' @export
statbank_search <- function(text, lang = "da", refresh = FALSE) {
  tbl <- statbank_tables(lang = lang, refresh = refresh)
  hit <- grepl(text, paste(tbl$title, tbl$id), ignore.case = TRUE)
  tbl[hit, ]
}

#' Get the metadata for a Greenland Statbank table
#'
#' Fetches a table's title and variables: codes, display texts, and the
#' values each variable can take.
#'
#' @param table The table's path in the tree, e.g.
#'   `"BE/BE01/BEXSAT1.PX"`. A bare table id (e.g. `"BEXSAT1.PX"`) also
#'   works once the table list has been fetched with [daos::statbank_tables()]
#'   or [daos::statbank_search()] in the same session.
#' @inheritParams statbank_nodes
#'
#' @return A list with `title`, `path`, and `variables`, where
#'   `variables` is a tibble with columns `code`, `text`, `values`
#'   (list), `valueTexts` (list), `elimination`, and `time`.
#'
#' @examples
#' \dontrun{
#' meta <- statbank_meta("BE/BE01/BEXSAT1.PX")
#' meta$variables
#' }
#'
#' @seealso [daos::statbank_get()]
#'
#' @importFrom cli cli_abort
#' @export
statbank_meta <- function(table, lang = "da") {
  .sb_check_available()
  path <- .sb_resolve_table(table, lang)
  x <- .sb_fetch(path, lang)
  vars <- tibble::as_tibble(x$variables)
  if (!"elimination" %in% names(vars)) vars$elimination <- FALSE
  if (!"time" %in% names(vars))        vars$time        <- FALSE
  vars$elimination[is.na(vars$elimination)] <- FALSE
  vars$time[is.na(vars$time)]               <- FALSE
  list(title = x$title, path = path, variables = vars)
}

#' Download a table from the Greenland Statbank
#'
#' Fetches data for a table and returns it as a tibble in long format:
#' one column per variable and a `value` column with the numbers.
#'
#' Selections are passed as named arguments. Names are matched against
#' the variable codes *and* their display texts, and values against both
#' value codes and value texts, so
#' `statbank_get("BE/BE01/BEXSAT1.PX", tid = 2024, art = "Antal")` works
#' without knowing the internal codes. Matching ignores case and folds
#' Danish letters (`foedested` matches `fødested`). Use `"*"` to select
#' all values; variables that are not mentioned default to all values.
#'
#' By default, columns are named by the variables' display texts in the
#' chosen language, and cells hold the display texts of the values. Set
#' `.col_names = "code"` and/or `.values = "code"` to get the internal
#' codes instead, e.g. when a coded column (such as sex as 0/1) is
#' wanted for joins or modelling. The option arguments are dot-prefixed
#' so they can never collide with a variable name in `...`.
#'
#' @inheritParams statbank_meta
#' @param ... Named selections, one per variable. Values can be value
#'   codes, value texts, or `"*"` for all.
#' @param .col_names `"text"` (default) names the columns by the
#'   variables' display texts; `"code"` uses the variable codes.
#' @param .values `"text"` (default) fills the cells with value display
#'   texts; `"code"` uses the value codes.
#' @param .type_convert If `TRUE` (default), the result is passed
#'   through [readr::type_convert()], so e.g. a year column comes back
#'   numeric. Set to `FALSE` to keep every variable column as character.
#'
#' @return A tibble with one column per variable and a `value` column.
#'
#' @examples
#' \dontrun{
#' df <- statbank_get(
#'   "BE/BE01/BEXSAT1.PX",
#'   tid = c(2023, 2024, 2025),
#'   art = "Antal"
#' )
#'
#' # Codes instead of display texts, no type conversion:
#' df <- statbank_get(
#'   "BE/BE01/BEXSAT1.PX",
#'   tid = 2024,
#'   .col_names = "code",
#'   .values = "code",
#'   .type_convert = FALSE
#' )
#' }
#'
#' @seealso [daos::statbank_meta()], [daos::statbank_search()], [daos::statbank_app()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang list2
#' @importFrom readr type_convert
#' @export
statbank_get <- function(table, ..., lang = "da",
                         .col_names = c("text", "code"),
                         .values = c("text", "code"),
                         .type_convert = TRUE) {
  .sb_check_available()
  .col_names <- match.arg(.col_names)
  .values    <- match.arg(.values)

  meta  <- statbank_meta(table, lang)
  sels  <- .sb_match_selection(meta$variables, rlang::list2(...))
  query <- list(
    query = lapply(names(sels), function(code) {
      if (identical(sels[[code]], "*")) {
        list(code = code, selection = list(filter = "all", values = I("*")))
      } else {
        list(code = code, selection = list(filter = "item", values = I(sels[[code]])))
      }
    }),
    response = list(format = "json-stat2")
  )
  x   <- .sb_post(meta$path, query, lang)
  out <- .sb_parse_jsonstat(x, col_names = .col_names, values = .values)

  if (.type_convert && nrow(out) > 0 &&
      any(vapply(out, is.character, logical(1)))) {
    out <- suppressMessages(readr::type_convert(out))
  }
  out
}

# --- internals ---------------------------------------------------------------

.sb_check_available <- function() {
  for (pkg in c("curl", "jsonlite")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required. Install with {.code install.packages('{pkg}')}.")
  }
}

.sb_url <- function(path, lang) {
  url <- paste0(.sb_base, "/", lang, "/Greenland")
  if (nzchar(path)) url <- paste0(url, "/", path)
  utils::URLencode(url)
}

.sb_handle <- function() {
  h <- curl::new_handle()
  curl::handle_setopt(h, useragent = "daos R package (https://github.com/dataniel/daos)")
  h
}

.sb_fetch <- function(path, lang) {
  res <- curl::curl_fetch_memory(.sb_url(path, lang), .sb_handle())
  if (res$status_code != 200) {
    cli::cli_abort(c(
      "The statbank returned status {res$status_code} for {.path {path}}.",
      "i" = "Check the path and language, or try again later."
    ))
  }
  jsonlite::fromJSON(rawToChar(res$content))
}

.sb_post <- function(path, query, lang) {
  body <- jsonlite::toJSON(query, auto_unbox = TRUE)
  h <- .sb_handle()
  curl::handle_setopt(h, postfields = body)
  curl::handle_setheaders(h, "Content-Type" = "application/json")
  res <- curl::curl_fetch_memory(.sb_url(path, lang), h)
  if (res$status_code != 200) {
    cli::cli_abort(c(
      "The statbank returned status {res$status_code} for the data query.",
      "i" = "A too-large selection or a malformed value can cause this."
    ))
  }
  jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
}

.sb_strip_html <- function(x) {
  x <- gsub("<[^>]+>", " ", x)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

.sb_resolve_table <- function(table, lang) {
  if (grepl("/", table, fixed = TRUE)) return(table)
  cached <- .sb_cache[[paste0("tables_", lang)]]
  if (is.null(cached)) {
    cli::cli_abort(c(
      "{.val {table}} is not a path, and the table list has not been fetched yet.",
      "i" = "Use the full path (e.g. {.val BE/BE01/BEXSAT1.PX}), or run {.fun statbank_tables} or {.fun statbank_search} first."
    ))
  }
  hit <- which(tolower(cached$id) == tolower(table))
  if (length(hit) == 0) {
    cli::cli_abort("No table with id {.val {table}} in the table list.")
  }
  paste(cached$path[hit[1]], cached$id[hit[1]], sep = "/")
}

# Case-insensitive comparison key that also folds Danish letters to
# their ASCII spellings, so `foedested` matches `fødested`.
.sb_fold <- function(x) {
  x <- tolower(x)
  x <- gsub("\u00e6", "ae", x, fixed = TRUE)
  x <- gsub("\u00f8", "oe", x, fixed = TRUE)
  x <- gsub("\u00e5", "aa", x, fixed = TRUE)
  x
}

# Match user selections (named by variable code or text, values by value
# code or value text) to the table's variables. Returns a named list,
# variable code -> character vector of value codes, with "*" for all.
# Variables the user does not mention default to "*".
.sb_match_selection <- function(vars, sels) {
  out <- stats::setNames(as.list(rep("*", nrow(vars))), vars$code)
  if (length(sels) == 0) return(out)
  if (is.null(names(sels)) || any(names(sels) == "")) {
    cli::cli_abort("All selections must be named by variable, e.g. {.code tid = 2024}.")
  }

  for (nm in names(sels)) {
    i <- which(.sb_fold(vars$code) == .sb_fold(nm) | .sb_fold(vars$text) == .sb_fold(nm))
    if (length(i) == 0) {
      cli::cli_abort(c(
        "No variable matches {.val {nm}}.",
        "i" = "Available: {.val {vars$text}} (codes: {.val {vars$code}})."
      ))
    }
    i <- i[1]
    wanted <- as.character(sels[[nm]])
    if (identical(wanted, "*")) next

    codes  <- vars$values[[i]]
    texts  <- vars$valueTexts[[i]]
    mapped <- vapply(wanted, function(w) {
      j <- which(.sb_fold(codes) == .sb_fold(w))
      if (length(j) == 0) j <- which(.sb_fold(texts) == .sb_fold(w))
      if (length(j) == 0) {
        cli::cli_abort(c(
          "No value matches {.val {w}} for variable {.val {vars$text[i]}}.",
          "i" = "Examples of valid values: {.val {utils::head(texts, 5)}}."
        ))
      }
      codes[j[1]]
    }, character(1))
    out[[vars$code[i]]] <- unname(mapped)
  }
  out
}

# Turn a parsed json-stat2 response into a long tibble. The `id` and
# `size` fields define the dimensions actually present in the value
# array (the dimension list can hold extra, eliminated dimensions). The
# value array is row-major: the last dimension varies fastest.
.sb_parse_jsonstat <- function(x, col_names = "text", values = "text") {
  ids  <- unlist(x$id)
  size <- unlist(x$size)
  k    <- length(ids)

  cols <- vector("list", k)
  for (j in seq_len(k)) {
    dim    <- x$dimension[[ids[j]]]
    index  <- unlist(dim$category$index)
    codes  <- names(index)[order(unlist(index))]
    content <- if (values == "code") {
      codes
    } else {
      unname(unlist(dim$category$label)[codes])
    }
    inner  <- if (j < k) prod(size[(j + 1):k]) else 1
    outer  <- if (j > 1) prod(size[seq_len(j - 1)]) else 1
    cols[[j]] <- rep(rep(content, each = inner), times = outer)
  }

  names(cols) <- if (col_names == "code") {
    ids
  } else {
    vapply(seq_len(k), function(j) {
      lbl <- x$dimension[[ids[j]]]$label
      tolower(if (is.null(lbl) || !nzchar(lbl)) ids[j] else lbl)
    }, character(1))
  }
  names(cols) <- make.unique(names(cols))

  value <- vapply(x$value, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
  tibble::as_tibble(c(cols, list(value = value)))
}
