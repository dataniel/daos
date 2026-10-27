#' Assert that key columns identify each row uniquely
#'
#' A checkpoint for keys: every combination of the selected columns must
#' occur at most once. On failure the duplicated rows are reported (and
#' dumped, see [expect_empty()]) grouped by a `dupid` column, so each group
#' of copies can be inspected together. Returns `data`, so it can sit in the
#' middle of a pipeline.
#'
#' The most valuable place for it is just before a join. A lookup table with
#' a duplicated key makes `left_join()` silently multiply rows; checking the
#' key first turns that into an explicit message:
#'
#' ```r
#' codes |>
#'   expect_unique(branche, abort_msg = "Codebook has duplicate codes") |>
#'   left_join(x = df, by = "branche")
#' ```
#'
#' This is [flag_duplicates()] + `filter(isdup)` + [expect_empty()] in one
#' step.
#'
#' @param data A data frame or tibble.
#' @param ... Key columns (tidy-select). If omitted, all columns are used,
#'   which checks for fully duplicated rows.
#' @inheritParams expect_empty
#' @param warn_msg Message shown (and logged) when duplicates exist and no
#'   `abort_msg` is set. Defaults to a description naming the key columns.
#'
#' @return `data` invisibly, unchanged.
#'
#' @examples
#' # Success: one row per model
#' dplyr::distinct(ggplot2::mpg, model) |>
#'   expect_unique(model)
#'
#' # Warning: models appear in several years and variants
#' ggplot2::mpg |>
#'   expect_unique(model, year)
#'
#' \dontrun{
#' df |>
#'   expect_unique(cvr, year, abort_msg = "Duplicate company-years")
#' }
#'
#' @seealso [flag_duplicates()], [expect_empty()], [expect_none()]
#'
#' @export
expect_unique <- function(data, ...,
                          success_msg = NULL,
                          warn_msg    = NULL,
                          abort_msg   = NULL,
                          log         = getOption("daos.check_log"),
                          dump        = getOption("daos.check_dump")) {

  check_data_frame(data)
  keys <- if (...length() == 0) "all columns" else
    paste(names(dplyr::select(data, ...)), collapse = ", ")

  flagged <- flag_duplicates(data, ...)
  dups <- flagged[flagged$isdup, setdiff(names(flagged), "isdup")]
  dups <- dups[order(dups$dupid), ]

  label <- abort_msg %||% warn_msg
  report_check(
    violations  = dups,
    success_msg = success_msg %||%
      if (is.null(label)) paste0("Unique on ", keys) else paste0("Check passed: ", label),
    fail_msg    = label %||% paste0("Duplicate rows on ", keys),
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump
  )
  invisible(data)
}
