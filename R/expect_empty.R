#' Assert that a data frame is empty
#'
#' A pipeline-friendly validation checkpoint. Express a rule as "the set of
#' violations must be empty", build that set with an ordinary `filter()`, and
#' pipe it in. Emits a success alert when the data frame has zero rows,
#' otherwise warns or aborts with the number of offending rows and the first
#' few printed as a tibble. To keep all of them, write them to disk with
#' `dump` (see below).
#'
#' The rows are deliberately not kept in the session afterwards: on a
#' population register a failed check can hold millions of rows, and they
#' would stay in memory until the next failure.
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

# Group ids for the key columns, without sorting or copying them ----------
#
# Sorting a character key such as cpr is the expensive step on a population
# register, and grouping does not need an order. R stores each distinct
# string once, and data.table::chmatch() uses that to find, for every row,
# the first row with the same string in one linear pass. The ids below are
# built from that: dense integers 1..k in order of first appearance, with
# NA as a value of its own, as in duplicated().

# Dense ids from "index of the first row with this value", in one pass.
dense_ids <- function(first) {
  head <- first == seq_along(first)
  map <- integer(length(first))
  map[head] <- seq_len(sum(head))
  map[first]
}

# Per row, the id of its combination of `cols`. Columns are combined by
# arithmetic, `(id - 1) * k + code`, and only re-numbered through match()
# when the id space would outgrow the data. The number of groups (or an
# upper bound on it) is kept in the "n" attribute, for tabulate().
group_ids <- function(data, cols) {
  n  <- nrow(data)
  id <- rep.int(1L, n)
  k  <- 1
  for (col in cols) {
    x <- data[[col]]
    if (is.factor(x)) x <- as.integer(x)
    code <- dense_ids(if (is.character(x)) data.table::chmatch(x, x) else match(x, x))
    kx   <- max(code, 0L)
    if (k * kx <= 4 * n && k * kx <= .Machine$integer.max) {
      id <- (id - 1L) * kx + code
      k  <- k * kx
    } else {
      id <- (id - 1) * kx + code
      id <- dense_ids(match(id, id))
      k  <- max(id, 0L)
    }
  }
  structure(id, n = k)
}

# Last write wins in `x[i] <- v`, so writing in descending order of `value`
# leaves each group's minimum: a grouped min() without sorting the groups.
min_by <- function(value, group, n_groups) {
  o <- order(value, decreasing = TRUE, method = "radix")
  out <- rep(NA_integer_, n_groups)
  out[group[o]] <- value[o]
  out
}

max_by <- function(value, group, n_groups) -min_by(-value, group, n_groups)

# The first row of each group, by the same last-write-wins rule.
first_row_by <- function(group, n_groups) {
  out <- integer(n_groups)
  rows <- rev(seq_along(group))
  out[group[rows]] <- rows
  out
}

# Reports a violation set: success alert when empty, otherwise warning or
# error of class `daos_check_failure` carrying the rows. `key` names the
# columns the rule is about; they are moved to the front so a narrow console
# cuts the other columns, not these. `group` names a column grouping the rows
# (`dupid`, `overlap_id`), counted in the summary. `call` defaults to the
# exported checkpoint that called this, so errors name that function.
report_check <- function(violations, success_msg, fail_msg, abort,
                         log = NULL, dump = NULL,
                         key = character(), group = NULL,
                         call = rlang::caller_env()) {
  n <- nrow(violations)

  if (n == 0) {
    cli::cli_alert_success("{success_msg}")
    write_check_log(log, "✔", success_msg, n)
    return(invisible(TRUE))
  }

  violations <- tibble::as_tibble(violations)
  violations <- violations[c(intersect(c(group, key), names(violations)),
                             setdiff(names(violations), c(group, key)))]

  dump_file <- dump_violations(violations, dump, fail_msg)
  write_check_log(log, if (abort) "✖" else "!", fail_msg, n, dump_file)

  n_groups <- if (!is.null(group)) length(unique(violations[[group]]))
  bullets <- c(
    "{fail_msg}",
    "i" = if (is.null(n_groups)) "{n} row{?s} found:"
          else "{n} row{?s} in {n_groups} group{?s}:",
    preview_rows(violations, n = preview_n),
    if (!is.null(dump_file)) c("i" = "All rows written to {.path {dump_file}}.")
    else if (n > preview_n) c("i" = "Set {.arg dump} or {.code options(daos.check_dump = )} to write all rows to a CSV file.")
  )

  signal <- if (abort) cli::cli_abort else cli::cli_warn
  signal(bullets, class = "daos_check_failure", violations = violations,
         call = call)
  invisible(FALSE)
}

# Rows shown in a failure message
preview_n <- 5

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

# The first rows as a tibble printout, one escaped cli bullet per line. The
# "# A tibble" header repeats the summary bullet and the "print(n = ...)"
# hint does not apply to a message, so both are dropped. Spaces become
# non-breaking, because cli would otherwise collapse the column alignment.
preview_rows <- function(data, n = 5, width = cli::console_width() - 2) {
  if (ncol(data) == 0) return(character())
  lines <- format(tibble::as_tibble(data), n = n, width = width)
  lines <- lines[!grepl("^# A tibble|print\\(n = ", cli::ansi_strip(lines))]
  lines <- gsub(" ", " ", cli_escape(sub("\\s+$", "", lines)), fixed = TRUE)
  stats::setNames(lines, rep(" ", length(lines)))
}

cli_escape <- function(x) {
  gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
}
