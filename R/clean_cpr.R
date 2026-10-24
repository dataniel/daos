#' Standardise CPR numbers
#'
#' Cleans a vector of Danish CPR numbers to the canonical 10-digit form:
#' dashes and spaces are stripped, and nine-digit values consisting only of
#' digits are zero-padded on the left. The padding is well-founded: birth
#' days 01-09 mean that roughly a third of all CPR numbers legitimately
#' start with a zero, which Excel silently drops from numeric cells.
#'
#' This is standardisation only, not validation. Values that cannot be
#' brought to 10 digits are returned cleaned but otherwise untouched, so a
#' malformed number stays visibly malformed for downstream checks. Use
#' [daos::add_cpr_info()] for validity, or pipe through a checkpoint
#' (see `vignette("validation")`).
#'
#' [daos::add_cpr_info()] applies this cleaning internally for its
#' calculations, while preserving the original CPR column in its output.
#' Both functions use the same native normalisation rules. Cleaning is
#' optional before `add_cpr_info()`; use it when you need a standardised
#' identifier for joins or export. Already clean character vectors are
#' returned without allocating a replacement vector.
#'
#' @param x A character vector of CPR numbers. Numeric vectors are
#'   converted with `as.character()` first.
#'
#' @return A character vector of the same length.
#'
#' @examples
#' clean_cpr(c("111111-1118", "1111111118", "101004007", NA))
#'
#' # Typical use: standardise the join key on both sides
#' # df  |> dplyr::mutate(pnr = clean_cpr(pnr))
#'
#' @seealso [daos::add_cpr_info()], [daos::clean_cvr()]
#'
#' @export
clean_cpr <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  .Call(C_daos_clean_cpr, x)
}
