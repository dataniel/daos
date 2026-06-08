#' Write a Greenlandic TA file
#'
#' Writes a data frame to a Greenlandic TA fixed-width file. Writes the nine
#' columns `nrnr`, `trans`, `brch`, `bas`, `eng`, `det`, `afg`, `moms`, and
#' `kbx`. Numeric columns are written without decimal places; character
#' columns are left-aligned in their field.
#'
#' If `moms` is absent from `x`, it is derived automatically: `NA` for rows
#' where `trans` is `"0100"` or `"0700"` (no VAT in Greenland), `0` otherwise.
#'
#' @param x A data frame with exactly the columns `nrnr`, `trans`, `brch`,
#'   `bas`, `eng`, `det`, `afg`, and `kbx`. `moms` is optional; if absent it
#'   is derived automatically (see Details). Any other columns cause an error.
#' @param path Path to write to.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' write_ta(df, "ta.file")
#' }
#'
#' @export
write_ta <- function(x, path) {
  ta_cols <- c("nrnr", "trans", "brch", "bas", "eng", "det", "afg", "moms", "kbx")

  extra <- setdiff(names(x), ta_cols)
  if (length(extra) > 0) {
    stop("write_ta() only supports the 9 TA columns. Remove: ",
         paste(extra, collapse = ", "))
  }

  if (!"moms" %in% names(x)) {
    message("`moms` not found in x -- generating: NA for trans 0100/0700, 0 otherwise.")
    x$moms <- ifelse(x$trans %in% c("0100", "0700"), NA_real_, 0)
  }

  fmt_str <- function(v, width) {
    formatC(ifelse(is.na(v), "", as.character(v)), width = width, flag = "-")
  }

  fmt_num <- function(v, width) {
    ifelse(
      is.na(v),
      formatC("", width = width),
      formatC(as.double(v), format = "f", digits = 0, width = width)
    )
  }

  lines <- vapply(seq_len(nrow(x)), function(i) {
    paste0(
      fmt_str(x$nrnr[i],   5), " ",
      fmt_str(x$trans[i],  6), " ",
      fmt_str(x$brch[i],   4), " ",
      fmt_num(x$bas[i],   13), " ",
      fmt_num(x$eng[i],   11), " ",
      fmt_num(x$det[i],   11), " ",
      fmt_num(x$afg[i],   11), " ",
      fmt_num(x$moms[i],  11), " ",
      fmt_num(x$kbx[i],   11)
    )
  }, character(1))

  writeLines(lines, path)
  invisible(path)
}
