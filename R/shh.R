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
#' shh(message("this message will not appear"))
#' shh(warning("this warning will not appear"))
#'
#' # Typical use: load packages without startup text
#' \dontrun{
#' shh(library(tidyverse))
#' }
#'
#' @export
shh <- function(expr) {
  suppressMessages(suppressWarnings(expr))
}
