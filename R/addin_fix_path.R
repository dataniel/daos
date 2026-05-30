# Matches Windows drive paths (C:\...) and UNC paths (\\server\...)
# and replaces backslashes with forward slashes within them.
# Avoids \(x) lambda syntax, \n, \t etc. by requiring path-like continuation.
.fix_windows_paths <- function(text) {
  stringr::str_replace_all(
    text,
    "(?:[A-Za-z]:\\\\|\\\\\\\\)[^\\s\"']*",
    function(m) gsub("\\\\", "/", m)
  )
}

#' RStudio addin: convert lines to R character vector
#'
#' Converts the selected text (one item per line) to an R character vector
#' expression, e.g. `c("a", "b", "c")`. Empty lines are ignored.
#'
#' @keywords internal
#' @export
addin_text_to_vector <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE))
    cli::cli_abort("Package {.pkg rstudioapi} is required to use this addin.")

  ctx <- rstudioapi::getActiveDocumentContext()
  sel <- ctx$selection[[1]]

  if (!nzchar(sel$text))
    cli::cli_abort("No text selected. Select one or more lines to convert.")

  items <- strsplit(sel$text, "\n")[[1]]
  items <- trimws(items)
  items <- items[nzchar(items)]

  result <- paste0('c(\n', paste0('  "', items, '"', collapse = ",\n"), '\n)')

  rstudioapi::modifyRange(sel$range, result, ctx$id)
}

#' RStudio addin: flip backslashes in selection
#'
#' Replaces all backslashes with forward slashes in the selected text.
#' Requires a selection.
#'
#' @keywords internal
#' @export
addin_flip_backslash <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE))
    cli::cli_abort("Package {.pkg rstudioapi} is required to use this addin.")

  ctx <- rstudioapi::getActiveDocumentContext()
  sel <- ctx$selection[[1]]

  if (!nzchar(sel$text))
    cli::cli_abort("No text selected. Select the text to flip backslashes in.")

  fixed <- gsub("\\\\", "/", sel$text)
  rstudioapi::modifyRange(sel$range, fixed, ctx$id)
}

#' RStudio addin: fix Windows paths
#'
#' Replaces backslashes with forward slashes in Windows-style paths
#' (`C:\...` or `\\server\...`). Operates on the selected text, or the
#' entire active file if nothing is selected.
#'
#' @keywords internal
#' @export
addin_fix_path <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE))
    cli::cli_abort("Package {.pkg rstudioapi} is required to use this addin.")

  ctx <- rstudioapi::getActiveDocumentContext()
  sel <- ctx$selection[[1]]

  if (nzchar(sel$text)) {
    rstudioapi::modifyRange(sel$range, .fix_windows_paths(sel$text), ctx$id)
  } else {
    cursor_pos <- ctx$selection[[1]]$range$start
    text  <- paste(ctx$contents, collapse = "\n")
    fixed <- .fix_windows_paths(text)
    rstudioapi::setDocumentContents(fixed, ctx$id)
    rstudioapi::setCursorPosition(cursor_pos, ctx$id)
  }
}
