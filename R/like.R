#' Regex matching with `NA` preservation
#'
#' An infix operator equivalent to [`grepl()`][base::grepl], but `NA` values
#' in `x` remain `NA` in the result instead of being coerced to `FALSE`.
#'
#' @param x A vector to search in.
#' @param pattern A regular expression (see [`regex`][base::regex]).
#'
#' @return A logical vector the same length as `x`.
#'
#' @examples
#' c("a1", "b2", NA, "c") %like% "\\d"
#'
#' # Use in dplyr pipelines:
#' if (requireNamespace("dplyr", quietly = TRUE)) {
#'   dplyr::filter(ggplot2::mpg, model %like% "\\d+")
#' }
#'
#' @export
`%like%` <- function(x, pattern) {
  result <- grepl(pattern, x)
  result[is.na(x)] <- NA
  result
}
