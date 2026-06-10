#' Flag duplicate rows
#'
#' Prepends two columns to a data frame: `isdup` (logical, `TRUE` when the row
#' appears more than once) and `dupid` (integer group identifier, `0` for
#' unique rows). Uses `data.table` internally for speed.
#'
#' @param data A data frame or tibble.
#' @param ... Columns used to identify duplicates (tidy-select). If omitted,
#'   all columns are used.
#'
#' @return A tibble with `isdup` and `dupid` prepended.
#'
#' @examples
#' # All columns
#' flag_duplicates(ggplot2::mpg)
#'
#' # Specific columns
#' flag_duplicates(ggplot2::mpg, manufacturer, model, year)
#'
#' # Combined with expect_empty() for a validation pipeline:
#' \dontrun{
#' ggplot2::mpg |>
#'   flag_duplicates() |>
#'   dplyr::filter(isdup) |>
#'   expect_empty(warn_msg = "Duplicate rows found")
#' }
#'
#' @seealso [daos::expect_empty()]
#'
#' @importFrom cli cli_abort
#' @importFrom dplyr select
#' @importFrom data.table as.data.table setcolorder
#' @importFrom tibble as_tibble
#' @export
flag_duplicates <- function(data, ...) {

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.")
  }

  cols <- if (...length() == 0) {
    base::names(data)
  } else {
    base::names(dplyr::select(data, ...))
  }

  non_atomic <- cols[!vapply(data[cols], is.atomic, logical(1))]
  if (length(non_atomic) > 0) {
    cli::cli_abort(c(
      "All grouping columns must be atomic.",
      "x" = "These columns are not atomic: {.var {non_atomic}}."
    ))
  }

  dt <- data.table::as.data.table(data)
  # Both columns in a single grouping pass; a per-group ifelse() is slow.
  dt[, c("isdup", "dupid") := list(.N > 1L, .GRP), by = cols]
  dt[!(isdup), dupid := 0L]

  data.table::setcolorder(dt, c("isdup", "dupid"))

  tibble::as_tibble(dt)
}
