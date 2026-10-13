#' Write a Greenlandic TA file in the new layout
#'
#' Writes a data frame to a Greenlandic TA fixed-width file in the new
#' 140-character layout, the one [read_ta2()] reads. For the old layout, use
#' [write_ta()].
#'
#' If `moms` is absent from `x`, it is derived automatically: `NA` for rows
#' where `trans` is `"0100"` or `"0700"` (no VAT in Greenland), `0` otherwise.
#'
#' @details
#' Both layouts are kept during the transition to the new TA system, and
#' afterwards so old files can still be produced. The `2` marks the new layout,
#' not a newer version of the same function.
#'
#' The file is guaranteed to read back through [read_ta2()] unchanged, by the
#' same rules as [write_ta()]: a value that does not fit its field is an error,
#' never truncated or rounded, and every offending value is listed at once.
#' Whole numbers are written without decimals; other numbers with the fewest
#' decimals that reproduce them exactly. `NA` is written as a blank field.
#'
#' Character fields are left-aligned, numeric fields right-aligned
#' (1-based character positions):
#'
#' | Column  | Positions | Width |
#' |---------|-----------|-------|
#' | nrnr    | 1--6      | 6     |
#' | *blank* | 7--16     | 10    |
#' | trans   | 17--21    | 5     |
#' | *blank* | 22--30    | 9     |
#' | brch    | 31--35    | 5     |
#' | bas     | 36--60    | 25    |
#' | eng     | 61--76    | 16    |
#' | det     | 77--92    | 16    |
#' | afg     | 93--108   | 16    |
#' | moms    | 109--124  | 16    |
#' | kbx     | 125--140  | 16    |
#'
#' @param x A data frame with exactly the columns `nrnr`, `trans`, `brch`,
#'   `bas`, `eng`, `det`, `afg`, and `kbx`. `moms` is optional; if absent it
#'   is derived automatically. Any other columns cause an error.
#' @param path Path to write to.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' write_ta2(df, "ta.file")
#' }
#'
#' @export
write_ta2 <- function(x, path) {
  ta_write(x, path,
           widths = c(nrnr = 6, trans = 5, brch = 5, bas = 25, eng = 16,
                      det = 16, afg = 16, moms = 16, kbx = 16),
           gaps = c(10, 9, 0, 0, 0, 0, 0, 0), fn = "write_ta2", reader = "read_ta2")
}
