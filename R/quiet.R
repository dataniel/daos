#' Suppress messages and warnings
#'
#' Evaluates an expression while suppressing all
#' [`message()`][base::message] and [`warning()`][base::warning] calls.
#' Useful when loading packages or calling verbose functions.
#'
#' @param expr An R expression to evaluate silently.
#'
#' @return The return value of `expr` (unchanged).
#'
#' @examples
#' quiet(message("this message will not appear"))
#' quiet(warning("this warning will not appear"))
#'
#' # Typical use: load packages without startup text
#' \dontrun{
#' quiet(library(tidyverse))
#' }
#'
#' @export
quiet <- function(expr) {
  suppressMessages(suppressWarnings(expr))
}
