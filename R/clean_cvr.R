#' Standardise CVR numbers
#'
#' Cleans a vector of Danish CVR numbers to the canonical 8-digit form:
#' dashes and spaces are stripped (`"12 34 56 78"` -> `"12345678"`), and a
#' leading `"DK"` VAT prefix is removed (`"DK12345678"` -> `"12345678"`).
#'
#' Unlike [daos::clean_cpr()], seven-digit values are *not* zero-padded:
#' a lost leading zero cannot be distinguished from a typo, and inventing
#' a digit would let a malformed number slip past downstream checks such
#' as a `cvr %like% "^\\d{8}$"` checkpoint. Values are returned cleaned
#' but otherwise untouched, so malformed numbers stay visibly malformed.
#'
#' @param x A character vector of CVR numbers. Numeric vectors are
#'   converted with `as.character()` first.
#'
#' @return A character vector of the same length.
#'
#' @examples
#' clean_cvr(c("DK12345678", "12 34 56 78", "12345678", NA))
#'
#' # Typical use: standardise the join key on both sides
#' # df  |> dplyr::mutate(cvr = clean_cvr(cvr))
#'
#' @seealso [daos::clean_cpr()]
#'
#' @export
clean_cvr <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  x <- gsub("[- ]", "", x)
  sub("^DK", "", x, ignore.case = TRUE)
}
