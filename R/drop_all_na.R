#' Drop all-`NA` rows and/or columns
#'
#' @description
#' Removes rows and/or columns that are entirely `NA` -- handy for tidying up
#' data after a join or import has left empty rows or unused columns behind.
#' Unlike `tidyr::drop_na()`, which drops a row as soon as it contains a single
#' `NA`, this only drops rows (or columns) where *every* value is `NA`.
#'
#' @param data A data frame or tibble.
#' @param which Which dimension(s) to clean: `"rows"`, `"cols"`, or both
#'   (the default). Partial matching is allowed.
#'
#' @return `data` with fully-`NA` rows and/or columns removed. The class of the
#'   input (data frame or tibble) is preserved.
#'
#' @examples
#' df <- tibble::tibble(
#'   a = c(1, NA, 3),
#'   b = c(NA, NA, NA),
#'   c = c("x", NA, "z")
#' )
#'
#' drop_all_na(df)                  # drops column b and the all-NA row
#' drop_all_na(df, which = "rows")  # only the all-NA row
#' drop_all_na(df, which = "cols")  # only column b
#'
#' @importFrom cli cli_abort
#' @importFrom dplyr select filter where if_all everything
#' @export
drop_all_na <- function(data, which = c("rows", "cols")) {

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.")
  }

  which <- match.arg(which, several.ok = TRUE)

  # Keep a column when it has rows that are not all `NA`. A column with no
  # rows is kept too -- an empty frame has no values to judge, so dropping its
  # columns (and losing the schema) would be surprising.
  if ("cols" %in% which) {
    data <- dplyr::select(data, dplyr::where(~ length(.x) == 0L || !all(is.na(.x))))
  }

  # Guard against a frame with no columns: `if_all(everything(), ...)` is
  # vacuously TRUE there, which would otherwise drop every row.
  if ("rows" %in% which && ncol(data) > 0L) {
    data <- dplyr::filter(data, !dplyr::if_all(dplyr::everything(), is.na))
  }

  data
}
