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
#' # Combined with a checkpoint from expectr for a validation pipeline:
#' \dontrun{
#' ggplot2::mpg |>
#'   flag_duplicates() |>
#'   dplyr::filter(isdup) |>
#'   expectr::expect_empty(warn_msg = "Duplicate rows found")
#' }
#'
#' @seealso [expectr::expect_unique()] to check a key,
#'   [expectr::expect_empty()]
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

# Group ids for the key columns, without sorting or copying them ----------
#
# Sorting a character key such as cpr is the expensive step on a population
# register, and grouping does not need an order. R stores each distinct
# string once, and data.table::chmatch() uses that to find, for every row,
# the first row with the same string in one linear pass. The ids below are
# built from that: dense integers 1..k in order of first appearance, with
# NA as a value of its own, as in duplicated(). expectr has the same engine
# for its key-based checkpoints.

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
