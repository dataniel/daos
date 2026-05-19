#' Extended null-coalescing operator
#'
#' Returns `default` when `x` is `NULL`, has length 0, consists entirely of
#' `NA` values, or (for character vectors) consists entirely of empty strings.
#' Otherwise returns `x` unchanged.
#'
#' More intuitive than [`rlang::%||%`][rlang::%||%] in data-cleaning contexts
#' where empty strings and all-`NA` vectors should be treated as missing.
#'
#' @param x Value to test.
#' @param default Fallback value returned when `x` is blank.
#'
#' @return `x` if non-blank, otherwise `default`.
#'
#' @examples
#' NULL %??% "default"
#' NA %??% 0
#' "" %??% "unknown"
#' c(NA, NA) %??% "missing"
#' 42 %??% 99
#'
#' @seealso [daos::is_blank()]
#'
#' @export
`%??%` <- function(x, default) {
  if (is.null(x) || length(x) == 0 || all(is.na(x)) ||
      (is.character(x) && all(x == ""))) {
    default
  } else {
    x
  }
}
