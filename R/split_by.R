#' Split a data frame into a named list by grouping columns
#'
#' Groups a data frame and splits it, automatically naming each element of
#' the resulting list from the unique group key values. Unlike the bare
#' [`dplyr::group_split()`], the returned list is always named.
#'
#' @param data A data frame or tibble.
#' @param ... Grouping columns (unquoted, tidy-select).
#' @param .sep Separator used to concatenate multiple group key values into a
#'   single list name. Default: `"_"`.
#'
#' @return A named list of tibbles.
#'
#' @examples
#' split_by(ggplot2::mpg, manufacturer)
#'
#' # Multiple grouping columns:
#' parts <- split_by(ggplot2::mpg, manufacturer, cyl)
#' names(parts)
#'
#' @seealso [daos::summon()] to retrieve objects matching a name pattern
#'
#' @importFrom dplyr group_keys group_by group_split
#' @export
split_by <- function(data, ..., .sep = "_") {
  keys   <- dplyr::group_keys(dplyr::group_by(data, ...))
  splits <- dplyr::group_split(data, ...)
  names(splits) <- do.call(paste, c(keys, sep = .sep))
  splits
}
