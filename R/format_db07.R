#' Format DB07 industry codes
#'
#' Danish DB07 industry codes (Dansk Branchekode 2007) appear in data both
#' with and without dots: `"011100"` in one register, `"01.11.00"` in a
#' classification table. `format_db07()` automatically handles these formats,
#' including partially dotted codes and whitespace, within the same vector.
#' Choose dotted or compact output with `format`; no input format is needed.
#' Dotted output inserts a dot after every second digit. Any aggregation
#' level is supported (`"01.1"`, `"01.11"`, `"01.11.00"`).
#'
#' No digits are invented: a code that lost its leading zero in Excel
#' (e.g. `11100` for `"011100"`) cannot be repaired safely, because a
#' 3- or 5-digit code is ambiguous between aggregation levels. Keep
#' industry codes as character columns to avoid the problem at the
#' source.
#'
#' @param x A character vector of DB07 codes. Numeric vectors are
#'   converted with `as.character()` first.
#' @param format Output format: `"dotted"` (default, e.g. `"01.11.00"`)
#'   or `"compact"` (digits without separators, e.g. `"011100"`).
#'
#' @return A character vector of the same length.
#'
#' @examples
#' format_db07(c("011100", "01.1100", "0111", "011", NA))
#' format_db07(c("011100", "01.11.00", "01 11 00"), format = "compact")
#'
#' # Typical use: match register data to a classification table
#' # df |> dplyr::mutate(branche = format_db07(branche, "compact"))
#'
#' @seealso [daos::clean_cpr()], [daos::clean_cvr()]
#'
#' @export
format_db07 <- function(x, format = c("dotted", "compact")) {
  format <- match.arg(format)
  if (!is.character(x)) x <- as.character(x)
  x <- gsub("[.[:space:]]", "", x)
  if (format == "compact") return(x)
  gsub("(\\d{2})(?=\\d)", "\\1.", x, perl = TRUE)
}
