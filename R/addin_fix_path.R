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

#' RStudio addin: paste path from clipboard
#'
#' Reads a Windows path from the clipboard, replaces backslashes with forward
#' slashes, and inserts it as a quoted R string at the cursor position.
#'
#' @keywords internal
#' @export
addin_paste_path <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE))
    cli::cli_abort("Package {.pkg rstudioapi} is required to use this addin.")

  raw <- utils::readClipboard()
  if (length(raw) == 0)
    cli::cli_abort("Clipboard is empty.")

  text  <- paste(raw, collapse = "\n")
  fixed <- gsub("\\\\", "/", text)
  rstudioapi::insertText(paste0('"', fixed, '"'))
}

# Resolve a piece of selected text to a filesystem path. A literal path that
# exists on disk is used as-is; otherwise the text is evaluated as R code in
# `envir` (e.g. an object or call that returns a path). Falls back to the
# unquoted literal so the caller can report a helpful "does not exist" error.
.resolve_path_text <- function(text, envir = globalenv()) {
  text <- trimws(text)
  if (!nzchar(text)) return(NULL)

  unquoted <- sub('^(["\'])(.*)\\1$', "\\2", text)
  if (file.exists(unquoted)) return(unquoted)

  val <- tryCatch(eval(parse(text = text), envir = envir), error = function(e) NULL)
  if (is.character(val) && length(val) == 1L && nzchar(val)) return(val)

  unquoted
}

# Extract the path-like token surrounding a cursor position on a single line,
# so the addin works when the cursor merely sits on an object/path without a
# selection. `col` is the 1-based cursor column (the gap before that
# character). Token characters cover bare R names and unquoted paths
# (letters, digits, `_ . : / \ ~ -`); spaces end the token, so paths with
# spaces still need to be selected. Returns "" when the cursor is on
# whitespace or an empty line.
.token_at_cursor <- function(line, col) {
  if (length(line) != 1L || is.na(line) || !nzchar(line)) return("")

  n <- nchar(line)
  col <- max(1L, min(as.integer(col), n + 1L))
  is_tok <- function(ch) grepl("[A-Za-z0-9_.:/\\\\~-]", ch)

  left <- col
  while (left > 1L && is_tok(substr(line, left - 1L, left - 1L))) left <- left - 1L
  right <- col - 1L
  while (right < n && is_tok(substr(line, right + 1L, right + 1L))) right <- right + 1L

  if (right < left) return("")
  substr(line, left, right)
}

# Open `path` in the system file explorer. A directory is opened directly; a
# file is opened by revealing it (selected) inside its containing folder.
.open_in_explorer <- function(path) {
  if (!file.exists(path))
    cli::cli_abort("Path does not exist: {.path {path}}")

  is_dir <- isTRUE(file.info(path)$isdir)

  if (.Platform$OS.type == "windows") {
    full <- normalizePath(path, winslash = "\\", mustWork = TRUE)
    # Launch through PowerShell's Start-Process so the Explorer window comes to
    # the foreground; `shell.exec`/`explorer` via cmd tend to open behind the
    # active window. A directory is opened directly; a file is revealed
    # (selected) in its folder via `/select`. The command is piped over stdin
    # (`-Command -`) so the path needs no command-line quoting and tolerates
    # spaces.
    arg <- if (is_dir) paste0('"', full, '"') else paste0('/select,"', full, '"')
    ps  <- paste0("Start-Process explorer.exe -ArgumentList '", arg, "'")
    system2("powershell", c("-NoProfile", "-Command", "-"),
            input = ps, stdout = FALSE, stderr = FALSE)
  } else {
    target <- if (is_dir) path else dirname(path)
    opener <- if (Sys.info()[["sysname"]] == "Darwin") "open" else "xdg-open"
    system2(opener, shQuote(normalizePath(target, mustWork = TRUE)))
  }
  invisible(path)
}

#' RStudio addin: open path in file explorer
#'
#' Opens a location in the system file explorer. The target is resolved to a
#' path in this order:
#' \itemize{
#'   \item the selected text, if any;
#'   \item otherwise the path-like token under the cursor (so you can just
#'     place the cursor on a path or an object holding one, no selection
#'     needed);
#'   \item otherwise the current working directory ([getwd()]).
#' }
#' An existing literal path is used as-is; anything else is evaluated as R
#' code (e.g. an object or call that returns a path). A resolved file is
#' revealed inside its containing folder; a directory is opened directly.
#'
#' @keywords internal
#' @export
addin_open_in_explorer <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE))
    cli::cli_abort("Package {.pkg rstudioapi} is required to use this addin.")

  ctx <- rstudioapi::getActiveDocumentContext()
  sel <- ctx$selection[[1]]

  text <- sel$text
  if (!nzchar(trimws(text))) {
    pos  <- sel$range$start
    line <- ctx$contents[pos[["row"]]]
    text <- .token_at_cursor(line, pos[["column"]])
  }

  path <- if (nzchar(trimws(text))) .resolve_path_text(text) else getwd()

  .open_in_explorer(path)
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
