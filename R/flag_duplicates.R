#' Flag duplicate rows
#'
#' Prepends two columns to a data frame: `isdup` (logical, `TRUE` when the row
#' appears more than once) and `dupid` (integer group identifier, `0` for
#' unique rows). The duplicate groups are numbered `1, 2, ...` in the order
#' they first appear. The key columns are neither copied nor sorted: rows
#' are grouped in one linear pass, which keeps it fast on full-population
#' registers with a character key such as cpr.
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
#' @importFrom data.table as.data.table
#' @importFrom tibble as_tibble
#' @export
flag_duplicates <- function(data, ...) {

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.")
  }

  cols  <- dup_cols(data, ...)
  dupid <- dup_ids(data, cols)

  out <- tibble::as_tibble(data)
  out <- out[setdiff(names(out), c("isdup", "dupid"))]
  tibble::add_column(out, isdup = dupid > 0L, dupid = dupid, .before = 1)
}

# The key columns for a duplicate check: the selection, or all columns.
dup_cols <- function(data, ..., call = rlang::caller_env()) {
  cols <- if (...length() == 0) names(data) else names(dplyr::select(data, ...))

  non_atomic <- cols[!vapply(unclass(data)[cols], is.atomic, logical(1))]
  if (length(non_atomic) > 0) {
    cli::cli_abort(c(
      "All grouping columns must be atomic.",
      "x" = "These columns are not atomic: {.var {non_atomic}}."
    ), call = call)
  }
  cols
}

# Per row: 0 for a unique key, otherwise the number of its duplicate group,
# counted in order of first appearance. Counting the rows per group id
# finds the duplicates without sorting the key, see group_ids().
dup_ids <- function(data, cols) {
  dupid <- integer(nrow(data))
  if (nrow(data) < 2 || length(cols) == 0) return(dupid)

  id   <- group_ids(data, cols)
  rows <- which(tabulate(id, attr(id, "n"))[id] > 1L)
  dupid[rows] <- match(id[rows], unique(id[rows]))
  dupid
}
