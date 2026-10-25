#' Write data frames to a presentable Excel file
#'
#' Writes an `.xlsx` workbook with formatting applied: the header row is
#' bold and frozen, `NA` values are shown as blank cells, and numeric columns
#' are formatted with a thousand separator and `digits` displayed decimals
#' (default zero) when the column contains at least one absolute value >= 1000. Underlying values are
#' preserved. Only the display format changes.
#'
#' Year-like columns are excluded from the number format automatically: a
#' numeric column where every non-`NA` value is a whole number between 1800
#' and 2200 is assumed to hold years, so `2020` is not displayed as `2.020`.
#' Set `detect_years = FALSE` to disable the heuristic, and use `skip_fmt`
#' for columns it cannot guess (e.g. numeric period codes like `202001`).
#'
#' Only the modern `.xlsx` format is supported. The old binary `.xls`
#' format cannot be written.
#'
#' Use `mode` to create a file, append sheets, replace selected sheets, or
#' overwrite the entire workbook. Sheet names are matched ignoring case.
#'
#' @param data A data frame or named list of data frames. A single data frame
#'   defaults to sheet name `"Sheet1"`; unnamed list elements get names
#'   `"Sheet1"`, `"Sheet2"`, etc.
#'   Sheet names must be valid Excel names and unique ignoring case.
#' @param path Path to the output `.xlsx` file.
#' @param mode One of `"new"` (default: create a file; fail if it exists),
#'   `"append"` (add sheets to an existing file; fail on name collisions),
#'   `"replace"` (replace matching sheets and add new ones in an existing file),
#'   or `"overwrite"` (write a fresh workbook, replacing the entire file if
#'   present). Replaced sheets retain their position; new sheets go at the end.
#'   Append and replace operate on whole sheets, not individual rows.
#' @param digits Number of displayed decimal places for automatically formatted
#'   numeric columns (0 to 15; default 0). Use `NULL` to disable automatic
#'   numeric formatting. Stored values are never rounded. Small-number columns,
#'   detected year columns and `skip_fmt` columns retain their default format.
#' @param as_table If `TRUE`, data is inserted as an Excel ListObject (table
#'   with filter arrows and banded rows). Default `FALSE`.
#' @param freeze_header If `TRUE` (default), freezes the first row.
#' @param skip_fmt Character vector of column names to exclude from the
#'   automatic number format.
#' @param detect_years If `TRUE` (default), numeric columns where every
#'   non-`NA` value is a whole number between 1800 and 2200 are excluded
#'   from the automatic number format.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' # New file with one sheet
#' write_excel(mtcars, "out.xlsx")
#'
#' # New file with multiple sheets
#' write_excel(list(Cars = mtcars, Iris = iris), "out.xlsx")
#'
#' # Add or replace sheets in an existing file
#' write_excel(list(Bilag = iris), "out.xlsx", mode = "append")
#' write_excel(list(Cars = mtcars), "out.xlsx", mode = "replace")
#'
#' # Replace the entire workbook
#' write_excel(mtcars, "out.xlsx", mode = "overwrite")
#'
#' # Insert as Excel table
#' write_excel(mtcars, "out.xlsx", as_table = TRUE)
#'
#' # Exclude a column from the number format
#' write_excel(df, "out.xlsx", skip_fmt = "periode")
#' write_excel(df, "out.xlsx", digits = 2)
#' write_excel(df, "out.xlsx", digits = NULL)
#' }
#'
#' @md
#'
#' @importFrom cli cli_abort
#' @importFrom rlang %||%
#' @export
write_excel <- function(
    data,
    path,
    mode          = c("new", "append", "replace", "overwrite"),
    as_table      = FALSE,
    freeze_header = TRUE,
    skip_fmt      = NULL,
    detect_years  = TRUE,
    digits        = 0
) {
  mode <- match.arg(mode)
  if (!is.null(digits) && (!is.numeric(digits) || length(digits) != 1L ||
      is.na(digits) || !is.finite(digits) || digits < 0 || digits > 15 || digits != trunc(digits)))
    cli::cli_abort("{.arg digits} must be NULL or a whole number from 0 to 15.")
  .xl_check_available()
  .xl_check_path(path)
  data_list <- .xl_as_list(data, "data")
  exists <- file.exists(path)
  if (exists && mode == "new")
    cli::cli_abort(c(
      "File {.path {path}} already exists.",
      "i" = 'Choose mode = "append", "replace", or "overwrite".'
    ))
  editing <- mode %in% c("append", "replace")
  if (editing && !exists)
    cli::cli_abort(c(
      "File {.path {path}} does not exist.",
      "i" = 'Use mode = "new" to create it.'
    ))

  wb <- if (editing) openxlsx2::wb_load(path) else openxlsx2::wb_workbook()
  sheet_order <- wb$sheet_names
  collisions <- tolower(names(data_list)) %in% tolower(sheet_order)
  if (mode == "append" && any(collisions))
    cli::cli_abort(c(
      "Sheet {.val {names(data_list)[collisions]}} already exists in {.path {path}}.",
      "i" = 'Use mode = "replace" to replace matching sheets.'
    ))
  for (nm in names(data_list)) {
    existing <- match(tolower(nm), tolower(wb$sheet_names))
    if (!is.na(existing)) {
      old_name <- wb$sheet_names[existing]
      sheet_order[match(old_name, sheet_order)] <- nm
      wb <- openxlsx2::wb_remove_worksheet(wb, sheet = old_name)
    } else {
      sheet_order <- c(sheet_order, nm)
    }
    wb <- .xl_add_sheet(wb, nm, data_list[[nm]], as_table, freeze_header,
                        skip_fmt, detect_years, digits)
  }
  wb <- openxlsx2::wb_set_order(wb, sheets = match(sheet_order, wb$sheet_names))
  openxlsx2::wb_save(wb, path, overwrite = mode != "new")
  invisible(path)
}

.xl_check_available <- function() {
  if (!requireNamespace("openxlsx2", quietly = TRUE))
    cli::cli_abort("Package {.pkg openxlsx2} is required. Install with {.code install.packages('openxlsx2')}.")
}

.xl_check_path <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext != "xlsx")
    cli::cli_abort(c(
      "{.arg path} must end in {.field .xlsx}, not {.field .{ext}}.",
      "i" = "The legacy binary {.field .xls} format cannot be written."
    ))
}

.xl_as_list <- function(x, arg_name) {
  if (is.data.frame(x)) return(list(Sheet1 = x))
  if (!is.list(x))
    cli::cli_abort("{.arg {arg_name}} must be a data frame or named list of data frames.")
  if (!length(x) || !all(vapply(x, is.data.frame, logical(1))))
    cli::cli_abort("{.arg {arg_name}} must be a non-empty list of data frames.")
  nms <- names(x) %||% character(length(x))
  if (anyNA(nms))
    cli::cli_abort("Sheet names must not be NA.")
  nms[nms == ""] <- paste0("Sheet", which(nms == ""))
  if (anyDuplicated(tolower(nms)))
    cli::cli_abort("Sheet names must be unique (ignoring case).")
  invalid <- nchar(nms) > 31L | grepl("[\\\\/?*\\[\\]:]", nms, perl = TRUE) |
    grepl("^'|'$", nms)
  if (any(invalid))
    cli::cli_abort("Invalid Excel sheet name(s): {.val {nms[invalid]}}.")
  names(x) <- nms
  x
}

# All non-NA values are whole numbers in the typical year range, so the
# column would be misread as e.g. 2.020 with a thousand separator.
.xl_is_yearlike <- function(x) {
  x <- x[!is.na(x)]
  length(x) > 0 && all(x == trunc(x)) && all(x >= 1800 & x <= 2200)
}

.xl_add_sheet <- function(wb, sheet_name, df, as_table, freeze_header,
                          skip_fmt, detect_years, digits) {
  df    <- as.data.frame(df)
  nrows <- nrow(df)
  ncols <- ncol(df)

  chr_cols <- vapply(df, function(x) is.character(x) || is.factor(x), logical(1))
  df[chr_cols] <- lapply(df[chr_cols], function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x
  })

  wb <- openxlsx2::wb_add_worksheet(wb, sheet_name)

  if (as_table) {
    wb <- openxlsx2::wb_add_data_table(wb, sheet_name, df, na = NULL)
  } else {
    wb <- openxlsx2::wb_add_data(wb, sheet_name, df, na = NULL)
    wb <- openxlsx2::wb_add_font(
      wb, sheet_name,
      bold = TRUE,
      dims = openxlsx2::wb_dims(rows = 1, cols = seq_len(ncols))
    )
  }

  if (freeze_header)
    wb <- openxlsx2::wb_freeze_pane(wb, sheet_name, first_row = TRUE)

  if (nrows > 0 && !is.null(digits)) {
    number_format <- paste0("#,##0", if (digits > 0) paste0(".", strrep("0", digits)) else "")
    num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    num_cols <- num_cols[vapply(num_cols, function(col) {
      any(abs(df[[col]]) >= 1000, na.rm = TRUE)
    }, logical(1))]
    fmt_cols <- setdiff(num_cols, skip_fmt %||% character(0))
    if (detect_years) {
      fmt_cols <- fmt_cols[!vapply(fmt_cols, function(col) {
        .xl_is_yearlike(df[[col]])
      }, logical(1))]
    }
    for (ci in which(names(df) %in% fmt_cols)) {
      wb <- openxlsx2::wb_add_numfmt(
        wb, sheet_name,
        dims   = openxlsx2::wb_dims(rows = seq(2, nrows + 1), cols = ci),
        numfmt = number_format
      )
    }
  }

  wb
}
