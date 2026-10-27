#' Assert that a data frame is empty
#'
#' A pipeline-friendly validation checkpoint. Express a rule as "the set of
#' violations must be empty", build that set with an ordinary `filter()`, and
#' pipe it in. Emits a success alert when the data frame has zero rows,
#' otherwise warns or aborts with the number of offending rows and a preview
#' of the first few.
#'
#' Messages are shown literally: braces are not interpolated, so regular
#' expressions such as `"^\\d{8}$"` are safe to use in a message.
#'
#' A failed check signals a condition of class `daos_check_failure` (a warning
#' or an error) that carries the offending rows in its `violations` field.
#' Scheduled pipelines can catch it and keep the rows:
#'
#' ```r
#' tryCatch(
#'   expect_empty(bad_rows, abort_msg = "Bad rows"),
#'   daos_check_failure = \(e) saveRDS(e$violations, "bad_rows.rds")
#' )
#' ```
#'
#' ## Logging and dumping
#'
#' `log` appends one line per check to a text file, and `dump` writes the
#' offending rows to a CSV file in a directory. Both default to a global
#' option, so a script can switch them on once at the top instead of
#' repeating the path in every check:
#'
#' ```r
#' options(
#'   daos.check_log  = f("log/{nowf()}_checks.log"),
#'   daos.check_dump = "log/violations"
#' )
#' ```
#'
#' A log line has the form `time | symbol | message | rows [| dump file]`:
#'
#' ```
#' 2026-06-11 09:00:03 | ✔ | Check passed: NA ids | 0 rows
#' 2026-06-11 09:00:03 | ! | Negative amounts | 3 rows | log/violations/20260611_090003_Negative_amounts.csv
#' ```
#'
#' @param data A data frame or tibble.
#' @param success_msg Message shown (and logged) when `data` is empty. If
#'   `NULL` (default), it is `"Check passed: <message>"` when `warn_msg` or
#'   `abort_msg` is given, so the log names every check that ran, and
#'   `"The dataset is empty."` otherwise.
#' @param warn_msg Message shown (and logged) when `data` is not empty and no
#'   `abort_msg` is set. Default: `"The dataset is not empty."`.
#' @param abort_msg If provided, `cli::cli_abort()` is called with this
#'   message when `data` is not empty. If `NULL` (default), a warning is
#'   issued instead.
#' @param log Optional path to a log file. The directory is created
#'   automatically. Defaults to `getOption("daos.check_log")`.
#' @param dump Optional directory. When the check fails, the offending rows
#'   are written there as a timestamped CSV file (UTF-8 with BOM, so Excel
#'   reads æøå correctly). Defaults to `getOption("daos.check_dump")`.
#'
#' @return `data` invisibly.
#'
#' @examples
#' # Success: no rows
#' data.frame() |> expect_empty()
#'
#' # Warning: unexpected rows
#' dplyr::filter(ggplot2::mpg, cyl > 6) |>
#'   expect_empty(warn_msg = "Eight-cylinder cars found")
#'
#' # Abort: treat unexpected rows as a hard error
#' \dontrun{
#' dplyr::filter(dplyr::starwars, height < 0) |>
#'   expect_empty(abort_msg = "Impossible: negative height")
#' }
#'
#' # With logging, set once for the whole script:
#' \dontrun{
#' options(daos.check_log = f("log/{nowf()}/checks.log"))
#'
#' dplyr::starwars |>
#'   dplyr::filter(name == "Harry Potter") |>
#'   expect_empty(warn_msg = "Harry Potter rows")
#' }
#'
#' @seealso [expect_none()] to check a condition without leaving the
#'   pipeline, [expect_unique()] for keys, [tally_violations()] to run many
#'   rules at once, and [flag_duplicates()].
#'
#' @export
expect_empty <- function(data,
                         success_msg = NULL,
                         warn_msg    = "The dataset is not empty.",
                         abort_msg   = NULL,
                         log         = getOption("daos.check_log"),
                         dump        = getOption("daos.check_dump")) {

  check_data_frame(data)

  label <- abort_msg %||% if (!missing(warn_msg)) warn_msg
  success_msg <- success_msg %||%
    if (is.null(label)) "The dataset is empty." else paste0("Check passed: ", label)

  report_check(
    violations  = data,
    success_msg = success_msg,
    fail_msg    = abort_msg %||% warn_msg,
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump
  )
  invisible(data)
}


# Shared engine for the expect_*() checkpoints ----------------------------

check_data_frame <- function(data, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.",
      call = call
    )
  }
}

# Reports a violation set: success alert when empty, otherwise warning or
# error of class `daos_check_failure` carrying the rows. `call` defaults to
# the exported checkpoint that called this, so errors name that function.
report_check <- function(violations, success_msg, fail_msg, abort,
                         log = NULL, dump = NULL,
                         call = rlang::caller_env()) {
  n <- nrow(violations)

  if (n == 0) {
    cli::cli_alert_success("{success_msg}")
    write_check_log(log, "✔", success_msg, n)
    return(invisible(TRUE))
  }

  dump_file <- dump_violations(violations, dump, fail_msg)
  write_check_log(log, if (abort) "✖" else "!", fail_msg, n, dump_file)

  bullets <- c(
    "{fail_msg}",
    "i" = "{n} row{?s} found:",
    preview_rows(violations),
    if (!is.null(dump_file)) c("i" = "All rows written to {.path {dump_file}}.")
  )

  signal <- if (abort) cli::cli_abort else cli::cli_warn
  signal(bullets, class = "daos_check_failure", violations = violations,
         call = call)
  invisible(FALSE)
}

write_check_log <- function(log, symbol, msg, n, dump_file = NULL) {
  if (is.null(log)) return(invisible())
  dir.create(dirname(log), recursive = TRUE, showWarnings = FALSE)
  line <- paste(c(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    symbol,
    msg,
    paste(n, if (n == 1) "row" else "rows"),
    dump_file
  ), collapse = " | ")
  cat(line, "\n", file = log, append = TRUE, sep = "")
}

dump_violations <- function(violations, dump, msg) {
  if (is.null(dump)) return(NULL)
  dir.create(dump, recursive = TRUE, showWarnings = FALSE)
  slug <- substr(gsub("^_+|_+$", "", gsub("[^[:alnum:]]+", "_", msg)), 1, 60)
  file <- file.path(dump, paste0(nowf("%Y%m%d_%H%M%S"), "_", slug, ".csv"))
  data.table::fwrite(violations, file, bom = TRUE)
  file
}

# The first rows as escaped cli bullets: `col = value, col = value`.
preview_rows <- function(data, n = 5, width = 100) {
  if (ncol(data) == 0) return(character())
  shown <- utils::head(as.data.frame(data), n)

  cells <- lapply(shown, format_cells)
  lines <- vapply(seq_len(nrow(shown)), function(i) {
    paste0(names(cells), " = ", vapply(cells, `[[`, "", i), collapse = ", ")
  }, character(1))

  too_wide <- nchar(lines) > width
  lines[too_wide] <- paste0(substr(lines[too_wide], 1, width - 3), "...")

  out <- stats::setNames(cli_escape(lines), rep(" ", length(lines)))
  if (nrow(data) > n) out <- c(out, " " = paste0("... and ", nrow(data) - n, " more"))
  out
}

format_cells <- function(x) {
  if (is.list(x)) {
    return(vapply(x, function(el) {
      if (!is.atomic(el)) return(paste0("<", class(el)[1], ">"))
      shown <- paste(utils::head(el, 5), collapse = ", ")
      paste0("[", shown, if (length(el) > 5) ", ...", "]")
    }, character(1)))
  }
  if (is.character(x) || is.factor(x)) {
    return(encodeString(as.character(x), quote = "\""))
  }
  # Element-wise, so one value's decimals don't pad the others
  vapply(seq_along(x), function(i) format(x[i], trim = TRUE, digits = 6), character(1))
}

cli_escape <- function(x) {
  gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
}
