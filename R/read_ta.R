#' Read a Greenlandic TA file
#'
#' Reads a Greenlandic TA file. Supports current prices (L), constant
#' prices (F), and prior-year prices (D) file types.
#'
#' @details
#' Column positions (0-based byte offsets):
#'
#' | Column  | Start | End |
#' |---------|-------|-----|
#' | nrnr    | 0     | 5   |
#' | trans   | 6     | 12  |
#' | brch    | 13    | 17  |
#' | bas     | 18    | 32  |
#' | eng     | 33    | 45  |
#' | det     | 46    | 58  |
#' | afg     | 59    | 71  |
#' | moms    | 72    | 84  |
#' | kbx     | 85    | 97  |
#' | prim    | 98    | 103 |
#' | afstm   | 104   | 107 |
#' | fval    | 108   | end |
#'
#' Columns `nrnr`, `trans`, `brch`, `afstm`, and `fval` are read as
#' character; all others as double.
#'
#' @param ta Path to the TA file.
#'
#' @return A tibble with the columns described above.
#'
#' @examples
#' \dontrun{
#' df <- read_ta("ta.file")
#' }
#'
#' @importFrom readr read_fwf cols col_character col_double
#' @export
read_ta <- function(ta) {
  ta_cols <- c("nrnr", "trans", "brch", "bas", "eng", "det",
               "afg", "moms", "kbx", "prim", "afstm", "fval")

  ta_pos <- list(
    begin    = c(0, 6, 13, 18, 33, 46, 59, 72, 85, 98, 104, 108),
    end      = c(5, 12, 17, 32, 45, 58, 71, 84, 97, 103, 107, NA),
    col_names = ta_cols
  )

  readr::read_fwf(
    file = ta,
    col_positions = ta_pos,
    col_types = readr::cols(
      nrnr  = readr::col_character(),
      trans = readr::col_character(),
      brch  = readr::col_character(),
      afstm = readr::col_character(),
      fval  = readr::col_character(),
      .default = readr::col_double()
    )
  )
}
