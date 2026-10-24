#' Drop rows or columns that are empty in selected columns
#'
#' `drop_empty_rows()` removes a row only when every selected column is
#' missing in that row. Other columns, such as identifiers, are kept but
#' do not influence the decision. `drop_empty_cols()` removes only selected
#' columns that are entirely missing.
#'
#' @param data A data frame or tibble.
#' @param ... Columns to inspect, using tidyselect syntax: bare names,
#'   ranges, `starts_with()`, `where(is.numeric)`, or `all_of(names)`.
#'   With no selection, all columns are inspected. Columns cannot be renamed.
#' @param blank Also consider empty strings and whitespace-only strings
#'   empty? Default `FALSE`. Applies to character and factor columns;
#'   retained values are never trimmed or changed. Zero and `FALSE` are
#'   not empty.
#'
#' @details
#' Missingness follows `is.na()`, including `NaN`. With `blank = TRUE`,
#' whitespace includes spaces, tabs, line breaks, and Unicode separators.
#' List columns use `is.na()` on each list element; their contents are not
#' recursively inspected. Matrix and data-frame columns must be excluded
#' from the selection.
#'
#' An empty selection returns the input unchanged. An input with zero rows
#' keeps its columns, preserving its schema. An input with zero columns
#' keeps its rows. Both functions preserve column types and row order.
#' Decisions use the entire input, including for grouped data. Remaining
#' grouping columns are preserved; removing a grouping column updates the
#' grouping metadata.
#'
#' To remove both empty rows and empty columns, call `drop_empty_rows()`
#' followed by `drop_empty_cols()`.
#'
#' @return The input data with empty rows or selected empty columns removed.
#' @examples
#' df <- tibble::tibble(
#'   id = 1:3,
#'   score_a = c(1, NA, NA),
#'   score_b = c(NA_real_, NA_real_, NA_real_),
#'   comment = c("ok", "", "  ")
#' )
#' drop_empty_rows(df, starts_with("score_"))
#' drop_empty_rows(df, comment, blank = TRUE)
#' drop_empty_cols(df, where(is.numeric))
#' df |> drop_empty_rows(starts_with("score_")) |> drop_empty_cols()
#' @export
drop_empty_rows <- function(data, ..., blank = FALSE) {
  selected <- .empty_selection(data, rlang::enquos(...), blank)
  if (!length(selected) || nrow(data) == 0L) return(data)
  empty <- rep(TRUE, nrow(data))
  for (i in selected) {
    empty <- empty & .empty_values(data[[i]], blank, names(data)[i])
  }
  if (!any(empty)) return(data)
  keep <- which(!empty)
  if (inherits(data, "data.table")) return(data[keep])
  data[keep, , drop = FALSE]
}

#' @rdname drop_empty_rows
#' @export
drop_empty_cols <- function(data, ..., blank = FALSE) {
  selected <- .empty_selection(data, rlang::enquos(...), blank)
  if (!length(selected) || nrow(data) == 0L) return(data)
  remove <- vapply(selected, function(i) {
    all(.empty_values(data[[i]], blank, names(data)[i]))
  }, logical(1))
  if (!any(remove)) return(data)
  keep <- setdiff(seq_along(data), selected[remove])
  if (inherits(data, "data.table")) return(data[, keep, with = FALSE])
  data[, keep, drop = FALSE]
}

.empty_selection <- function(data, dots, blank) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble.")
  }
  if (!is.logical(blank) || length(blank) != 1L || is.na(blank)) {
    cli::cli_abort("{.arg blank} must be TRUE or FALSE.")
  }
  if (anyNA(names(data)) || any(names(data) == "") || anyDuplicated(names(data))) {
    cli::cli_abort("{.arg data} must have unique, non-empty column names.")
  }
  if (!length(dots)) return(seq_along(data))
  unname(tidyselect::eval_select(rlang::expr(c(!!!dots)), data,
                               allow_rename = FALSE))
}

.empty_values <- function(x, blank, name) {
  empty <- is.na(x)
  if (!is.null(dim(empty))) {
    cli::cli_abort("Selected column {.var {name}} must be a one-dimensional vector. Exclude matrix or data-frame columns from the selection.")
  }
  if (blank && (is.character(x) || is.factor(x))) {
    # Match without trimming or modifying retained text or factor levels.
    empty <- empty | grepl("^[\\s\\p{Z}]*$", as.character(x), perl = TRUE)
  }
  empty
}
