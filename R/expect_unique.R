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
#' step, but faster: the full rows are only touched when there are
#' duplicates to report.
#'
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

  tbl <- check_table(data)
  key_cols <- if (...length() > 0) select_names(tbl, ...)
  keys <- if (is.null(key_cols)) "all columns" else paste(key_cols, collapse = ", ")

  if (is_remote(tbl)) {
    dups <- remote_duplicates(tbl, key_cols %||% colnames(tbl))
  } else {
    dupid <- dup_ids(data, dup_cols(data, ...))
    rows  <- which(dupid > 0L)
    rows  <- rows[order(dupid[rows])]
    dups  <- tibble::as_tibble(data)[rows, ]
    dups  <- tibble::add_column(dups[setdiff(names(dups), "dupid")],
                                dupid = dupid[rows], .before = 1)
  }

  label <- abort_msg %||% warn_msg
  report_check(
    violations  = dups,
    success_msg = success_msg %||%
      if (is.null(label)) paste0("Unique on ", keys) else paste0("Check passed: ", label),
    fail_msg    = label %||% paste0("Duplicate rows on ", keys),
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump,
    key         = key_cols,
    group       = "dupid"
  )
  invisible(data)
}
