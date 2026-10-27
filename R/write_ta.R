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
  ta_write(x, path,
           widths = c(nrnr = 5, trans = 6, brch = 4, bas = 13, eng = 11,
                      det = 11, afg = 11, moms = 11, kbx = 11),
           gaps = rep(1, 8), fn = "write_ta", reader = "read_ta")
}

# Shared by write_ta() and write_ta2(): the two layouts differ only in field
# widths and the blank gaps between fields. `gaps[i]` is the number of spaces
# between field i and field i + 1.
ta_write <- function(x, path, widths, gaps, fn, reader,
                     call = rlang::caller_env()) {
  str_cols <- c("nrnr", "trans", "brch")
  ta_cols <- names(widths)

  extra <- setdiff(names(x), ta_cols)
  if (length(extra) > 0) {
    cli::cli_abort(paste0(fn, "() only supports the 9 TA columns. Remove: ",
                          paste(extra, collapse = ", ")), call = call)
  }

  if (!"moms" %in% names(x)) {
    message("`moms` not found in x -- generating: NA for trans 0100/0700, 0 otherwise.")
    x$moms <- ifelse(x$trans %in% c("0100", "0700"), NA_real_, 0)
  }

  missing <- setdiff(ta_cols, names(x))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg x} is missing column{?s} {.field {missing}}.",
                   call = call)
  }

  fields <- lapply(ta_cols, function(col) {
    if (col %in% str_cols) ta_str(x[[col]]) else ta_num(x[[col]], widths[[col]])
  })
  names(fields) <- ta_cols

  problems <- unlist(lapply(ta_cols, function(col) {
    ta_field_problems(col, x[[col]], fields[[col]], widths[[col]],
                      is_str = col %in% str_cols, reader = reader)
  }))
  if (length(problems) > 0) {
    cli::cli_abort(c(
      "Cannot write {length(problems)} value{?s} so that {.fn {reader}} reads {cli::qty(length(problems))}{?it/them} back unchanged:",
      cap_bullets(problems)
    ), call = call)
  }

  padded <- lapply(ta_cols, function(col) {
    formatC(fields[[col]], width = widths[[col]],
            flag = if (col %in% str_cols) "-" else "")
  })
  # Interleave fields with their fixed gaps: field, gap, field, ..., field.
  pieces <- vector("list", 2 * length(padded) - 1)
  pieces[c(TRUE, FALSE)] <- padded
  pieces[c(FALSE, TRUE)] <- lapply(gaps, function(n) strrep(" ", n))

  writeLines(do.call(paste0, pieces), path)
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

ta_field_problems <- function(col, value, field, width, is_str, reader) {
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
      sprintf("has leading or trailing spaces, which %s() trims", reader)
    }
    sprintf("%s, row %d: %s %s.", col, i, shown, why)
  }, character(1))
}
