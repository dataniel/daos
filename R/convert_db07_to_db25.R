#' Convert industry codes between DB07 and DB25 using Statistics Denmark's keys
#'
#' Converts full six-digit codes in either direction using a bundled copy of Statistics
#' Denmark's correspondence table (source page updated 26 February 2026,
#' downloaded 24 October 2026). No network connection is needed at runtime.
#' Dots and whitespace are handled automatically, including mixed input.
#'
#' `convert_db07_to_db25()` converts DB07 to DB25; `convert_db25_to_db07()`
#' converts DB25 to DB07. The input classification must be chosen explicitly:
#' the same code can occur in both classifications with different meanings.
#'
#' With `method = "strict"`, codes with multiple destinations return
#' `NA` with a warning. With `method = "simple"`, the destination is taken
#' from DST's separate simplified conversion matrix for the chosen direction.
#' The reverse conversion does not invert the forward simplified matrix.
#' This is an approximation:
#' DST bases the choice on numbers of units, not economic activity. It cannot
#' establish the correct code for every individual business or allocate
#' turnover between split industries.
#'
#' Input must contain exactly six digits after removing dots and whitespace
#' and must occur in the source classification's key. Invalid lengths, unknown codes, and other
#' characters return `NA` with a warning. Missing input remains `NA` without
#' a warning. Leading zeroes are never guessed; keep codes as character data.
#' Aggregated codes are not supported.
#'
#' @param x A vector of full codes in the source classification, coerced to
#'   character if needed.
#' @param format Output format: `"dotted"` (default) or `"compact"`.
#' @param method `"strict"` (default) converts only codes with a single
#'   destination. `"simple"` uses DST's simplified conversion matrix.
#' @return A character vector of the same length and order as `x`.
#' @source [Statistics Denmark: DB25 and conversion tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende).
#'   The rebuild script `data-raw/db07_db25.R` records the source file URLs.
#' @examples
#' convert_db07_to_db25(c("011100", "01.49.10", NA))
#' convert_db07_to_db25("01.19.00", method = "simple", format = "compact")
#' convert_db25_to_db07("25.30.00", format = "compact")
#' # df |> dplyr::mutate(db25 = convert_db07_to_db25(db07))
#' @seealso [format_db07()]
#' @md
#' @export
convert_db07_to_db25 <- function(x, format = c("dotted", "compact"),
                                method = c("strict", "simple")) {
  format <- match.arg(format)
  method <- match.arg(method)
  convert_db_codes(x, format, method, db07_db25_key, db07_db25_simple, "DB07", "DB25")
}

#' @rdname convert_db07_to_db25
#' @export
convert_db25_to_db07 <- function(x, format = c("dotted", "compact"),
                                method = c("strict", "simple")) {
  format <- match.arg(format)
  method <- match.arg(method)
  convert_db_codes(x, format, method, db25_db07_key, db25_db07_simple, "DB25", "DB07")
}

convert_db_codes <- function(x, format, method, key, simple, from, to) {
  codes <- format_db07(x, "compact")
  missing <- is.na(codes)
  valid <- !missing & grepl("^[0-9]{6}$", codes) &
    codes %in% names(key)
  out <- rep(NA_character_, length(codes))
  if (any(!missing & !valid)) {
    warning(sum(!missing & !valid),
            " invalid or unknown ", from,
            " code(s); returning NA. Use full six-digit codes.",
            call. = FALSE)
  }
  if (method == "simple") {
    out[valid] <- unname(simple[codes[valid]])
  } else {
    candidates <- key[codes[valid]]
    ambiguous <- lengths(candidates) > 1L
    if (any(ambiguous)) {
      warning(sum(ambiguous),
              " ", from, " code(s) have multiple ", to, " destinations; returning NA. ",
              "Use method = 'simple' for DST's approximate mapping.",
              call. = FALSE)
    }
    out[valid] <- vapply(candidates, function(code) {
      if (length(code) == 1L) code else NA_character_
    }, character(1))
  }
  format_db07(out, format)
}
