#' Inspect possible classifications of mixed DB07 and DB25 industry codes
#'
#' Checks full six-digit industry codes against both bundled DST keys without
#' assigning a classification to codes present in both. Dots and whitespace
#' are removed automatically. Leading zeroes are not guessed.
#'
#' A code shared by DB07 and DB25 may have different meanings in each version.
#' Even identical labels do not establish identical definitions. Use source
#' classification metadata, the original industry text and its time context
#' to investigate shared codes before labelling or converting them.
#' This function neither converts codes nor changes the explicit version
#' requirement of [db_label()]. It supports full industry codes only.
#'
#' @param x A vector of full industry codes, coerced to character if needed.
#' @return A tibble with one row per input, preserving order and duplicates:
#'   `input` (original value as character), `code` (compact code), `status`
#'   (`"db07_only"`, `"db25_only"`, `"both"`, `"unknown"`, or `"missing"`),
#'   and `label_db07` and `label_db25`. Unknown includes malformed values and
#'   aggregated codes. Missing labels are `NA`. Diagnostic statuses are returned
#'   without warnings.
#' @source [Statistics Denmark: DB25 and conversion tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende).
#'   Uses the same bundled tables as [db_label()] and [convert_db07_to_db25()].
#' @examples
#' inspect_db(c("01.49.10", "014800", "25.30.00", "011200", "999999", NA))
#' # dplyr::bind_cols(df, inspect_db(df$dbkode))
#' @seealso [db_label()], [convert_db07_to_db25()], [convert_db25_to_db07()]
#' @md
#' @export
inspect_db <- function(x) {
  input <- as.character(x)
  code <- format_db07(input, "compact")
  in_db07 <- code %in% names(db07_db25_key)
  in_db25 <- code %in% names(db25_db07_key)
  status <- rep("unknown", length(code))
  status[in_db07 & !in_db25] <- "db07_only"
  status[in_db25 & !in_db07] <- "db25_only"
  status[in_db07 & in_db25] <- "both"
  status[is.na(code)] <- "missing"
  old <- unname(db07_labels[code])
  new <- unname(db25_labels[code])
  old[!in_db07] <- NA_character_
  new[!in_db25] <- NA_character_
  tibble::tibble(input = input, code = code, status = status,
                 label_db07 = old, label_db25 = new)
}
