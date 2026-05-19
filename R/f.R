#' String interpolation shorthand
#'
#' A short alias for [`glue::glue()`]. Interpolates R expressions enclosed in
#' `{}` inside a string. All arguments accepted by `glue::glue()` are
#' forwarded.
#'
#' @inheritParams glue::glue
#'
#' @return A character vector of interpolated strings.
#'
#' @examples
#' f("2 + 2 = {2 + 2}")
#' name <- "world"
#' f("Hello, {name}!")
#'
#' # Combine with nowf() for timestamped paths:
#' \dontrun{
#' f("data/export_{nowf('%Y%m%d')}.parquet")
#' f("log/{nowf()}/0-check.log")
#' }
#'
#' @seealso [daos::nowf()]
#'
#' @importFrom glue glue
#' @export
f <- glue::glue
