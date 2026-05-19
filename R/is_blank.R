#' Test whether a value is "blank"
#'
#' Returns `TRUE` if `x` is `NULL`, has length 0, contains only `NA` values,
#' or (for character vectors) contains only empty strings. More intuitive than
#' [`rlang::is_empty()`] in data-cleaning contexts.
#'
#' @param x Any R value.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_blank(NULL)        # TRUE
#' is_blank(NA)          # TRUE
#' is_blank("")          # TRUE
#' is_blank(c(NA, NA))   # TRUE
#' is_blank(0)           # FALSE
#' is_blank("text")      # FALSE
#'
#' # Compare with rlang::is_empty():
#' # is_empty("") returns FALSE, is_blank("") returns TRUE
#'
#' @seealso \code{\link[daos]{\%??\%}}
#'
#' @export
is_blank <- function(x) {
  is.null(x) ||
    length(x) == 0 ||
    all(is.na(x)) ||
    (is.character(x) && all(x == ""))
}
