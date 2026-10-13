#' Write a Greenlandic TA file
#'
#' Writes a data frame to a Greenlandic TA fixed-width file. Writes the nine
#' columns `nrnr`, `trans`, `brch`, `bas`, `eng`, `det`, `afg`, `moms`, and
#' `kbx`, in the positions [read_ta()] reads them from.
#'
#' If `moms` is absent from `x`, it is derived automatically: `NA` for rows
#' where `trans` is `"0100"` or `"0700"` (no VAT in Greenland), `0` otherwise.
#'
#' @details
#' The file is guaranteed to read back through [read_ta()] unchanged.
#' A fixed-width file has no delimiters, so a value wider than its field does
#' not fail: it pushes every following field out of position, and the file
#' still parses, just into the wrong columns. `write_ta()` therefore refuses to
#' write anything it cannot write exactly, and lists every offending value at
#' once.
#'
#' * Numbers are written with the fewest decimals that reproduce the value
#'   exactly, so whole numbers are written without decimals. A number whose
#'   exact form is wider than its field is an error, never rounded.
#' * Character values are left-aligned. Because [read_ta()] trims
#'   whitespace and reads blank fields as `NA`, values that are too long, empty,
#'   or start or end with a space are errors.
#' * `NA` is written as a blank field.
#'
#' | Column  | Width |
#' |---------|-------|
#' | nrnr    | 5     |
#' | trans   | 6     |
#' | brch    | 4     |
#' | bas     | 13    |
#' | eng, det, afg, moms, kbx | 11 |
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
  widths <- c(nrnr = 5, trans = 6, brch = 4, bas = 13, eng = 11,
              det = 11, afg = 11, moms = 11, kbx = 11)
  str_cols <- c("nrnr", "trans", "brch")
  ta_cols <- names(widths)

  extra <- setdiff(names(x), ta_cols)
  if (length(extra) > 0) {
    stop("write_ta() only supports the 9 TA columns. Remove: ",
         paste(extra, collapse = ", "))
  }

  if (!"moms" %in% names(x)) {
    message("`moms` not found in x -- generating: NA for trans 0100/0700, 0 otherwise.")
    x$moms <- ifelse(x$trans %in% c("0100", "0700"), NA_real_, 0)
  }

  missing <- setdiff(ta_cols, names(x))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg x} is missing column{?s} {.field {missing}}.")
  }

  fields <- lapply(ta_cols, function(col) {
    if (col %in% str_cols) ta_str(x[[col]]) else ta_num(x[[col]], widths[[col]])
  })
  names(fields) <- ta_cols

  problems <- unlist(lapply(ta_cols, function(col) {
    ta_field_problems(col, x[[col]], fields[[col]], widths[[col]],
                      is_str = col %in% str_cols)
  }))
  if (length(problems) > 0) {
    # Escape braces so values are shown literally, not interpolated by cli.
    shown <- gsub("([{}])", "\\1\\1", problems[seq_len(min(10, length(problems)))])
    names(shown) <- rep("x", length(shown))
    more <- length(problems) - length(shown)
    cli::cli_abort(c(
      "Cannot write {length(problems)} value{?s} so that {.fn read_ta} reads {?it/them} back unchanged:",
      shown,
      if (more > 0) c(" " = "... and {more} more")
    ))
  }

  padded <- lapply(ta_cols, function(col) {
    formatC(fields[[col]], width = widths[[col]],
            flag = if (col %in% str_cols) "-" else "")
  })

  # The single-space separators from paste() are the fixed gaps between fields.
  writeLines(do.call(paste, padded), path)
  invisible(path)
}

# Character field as written, before padding; NA becomes a blank field.
ta_str <- function(v) {
  ifelse(is.na(v), "", as.character(v))
}

# Shortest fixed-point form that parses back to exactly `v`, trying more
# decimals only for the values that need them. Values with no exact form
# within `width` characters are returned as NA and reported as problems.
ta_num <- function(v, width) {
  v <- as.double(v)
  out <- rep("", length(v))
  todo <- !is.na(v)
  out[todo] <- NA_character_
  for (digits in 0:(width - 2)) {
    if (!any(todo)) break
    s <- formatC(v[todo], format = "f", digits = digits)
    exact <- as.double(s) == v[todo]
    idx <- which(todo)[exact]
    out[idx] <- s[exact]
    todo[idx] <- FALSE
  }
  out
}

ta_field_problems <- function(col, value, field, width, is_str) {
  bad <- if (is_str) {
    !is.na(value) & (nchar(field) > width | field == "" | field != trimws(field))
  } else {
    is.na(field) | nchar(field) > width
  }
  rows <- which(bad)
  vapply(rows, function(i) {
    shown <- if (is_str) paste0('"', field[i], '"') else format(value[i], digits = 17)
    why <- if (!is_str) {
      sprintf("needs more than %d characters to be exact", width)
    } else if (nchar(field[i]) > width) {
      sprintf("is %d characters, the field holds %d", nchar(field[i]), width)
    } else if (field[i] == "") {
      "is empty and would read back as NA"
    } else {
      "has leading or trailing spaces, which read_ta() trims"
    }
    sprintf("%s, row %d: %s %s.", col, i, shown, why)
  }, character(1))
}
