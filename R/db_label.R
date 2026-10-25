#' Look up Danish industry labels for DB07 or DB25 codes
#'
#' Returns the Danish titles from Statistics Denmark's bundled classification
#' tables. Supports full six-digit industry codes, two-, three-, and four-digit
#' hierarchy codes, and uppercase section letters such as `"A"`.
#' Dots and whitespace are removed automatically, including mixed input.
#'
#' Always choose `version = "DB07"` or `version = "DB25"` explicitly.
#' Identical codes can have different meanings in the two classifications.
#' This function looks up labels, it does not convert between classifications.
#' Unknown or malformed codes return `NA` with a warning. Missing input stays
#' missing without a warning. Leading zeroes are never guessed, so keep codes
#' as character data. No internet connection is needed.
#'
#' @param x A vector of industry codes, coerced to character if needed.
#' @param version Required classification: `"DB25"` or `"DB07"`.
#' @return A character vector of Danish labels in the same order and with
#'   the same length as `x`.
#' @source [Statistics Denmark: DB25 and conversion tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende),
#'   sheets `3. DB25 Alle koder` and `4. DB07 Alle koder` in the branch key.
#'   Source page updated 26 February 2026; downloaded 24 October 2026.
#' @examples
#' db_label(c("011200", "01.12.00", NA), version = "DB25")
#' db_label("01.49.10", version = "DB07")
#' db_label(c("A", "01", "01.1", "01.11"), version = "DB25")
#' # df |> dplyr::mutate(branche_label = db_label(dbkode, version = "DB07"))
#' @seealso [format_db07()], [convert_db07_to_db25()], [convert_db25_to_db07()]
#' @md
#' @export
db_label <- function(x, version) {
  if (missing(version) || is.null(version)) {
    stop("Choose version = 'DB07' or version = 'DB25'.", call. = FALSE)
  }
  version <- match.arg(version, c("DB25", "DB07"))
  codes <- format_db07(x, "compact")
  labels <- if (version == "DB25") db25_labels else db07_labels
  out <- unname(labels[codes])
  invalid <- !is.na(codes) & is.na(out)
  if (any(invalid)) {
    warning(sum(invalid), " invalid or unknown ", version,
            " code(s); returning NA.", call. = FALSE)
  }
  out
}
