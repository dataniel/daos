#' Format DB07 industry codes with dots
#'
#' Danish DB07 industry codes (Dansk Branchekode 2007) appear in data both
#' with and without dots: `"011100"` in one register, `"01.11.00"` in a
#' classification table. `dbdot()` normalises to the dotted form by
#' stripping any existing dots and spaces and inserting a dot after every
#' second digit. It works at any aggregation level (`"01.1"`, `"01.11"`,
#' `"01.11.00"`) and is idempotent, so mixed input comes out uniform.
#'
#' The inverse (the bare-digit form) is simply
#' `gsub("[.]", "", x)`, so it has no function of its own.
#'
#' No digits are invented: a code that lost its leading zero in Excel
#' (e.g. `11100` for `"011100"`) cannot be repaired safely, because a
#' 3- or 5-digit code is ambiguous between aggregation levels. Keep
#' industry codes as character columns to avoid the problem at the
#' source.
#'
#' @param x A character vector of DB07 codes. Numeric vectors are
#'   converted with `as.character()` first.
#'
#' @return A character vector of the same length.
#'
#' @examples
#' dbdot(c("011100", "01.1100", "0111", "011", NA))
#'
#' # Typical use: match register data to a classification table
#' # df |> dplyr::mutate(branche = dbdot(branche))
#'
#' @seealso [daos::clean_cpr()], [daos::clean_cvr()]
#'
#' @export
dbdot <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  x <- gsub("[. ]", "", x)
  gsub("(\\d{2})(?=\\d)", "\\1.", x, perl = TRUE)
}
