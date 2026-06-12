#' Write data frames to a presentable Excel file
#'
#' Creates a new `.xlsx` workbook with formatting applied: the header row is
#' bold and frozen, `NA` values are shown as blank cells, and numeric columns
#' are formatted with a thousand separator and no displayed decimals (`#,##0`)
#' when the column contains at least one value >= 1000. Underlying values are
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
#' Use [daos::append_excel()] to add sheets to an existing file.
#'
#' @param data A data frame or named list of data frames. A single data frame
#'   defaults to sheet name `"Sheet1"`; unnamed list elements get names
#'   `"Sheet1"`, `"Sheet2"`, etc.
#' @param path Path to the output `.xlsx` file.
#' @param overwrite If `FALSE` (default), aborts when `path` already exists.
#'   Set to `TRUE` to replace the file.
#' @param as_table If `TRUE`, data is inserted as an Excel ListObject (table
#'   with filter arrows and banded rows). Default `FALSE`.
#' @param freeze_header If `TRUE` (default), freezes the first row.
#' @param skip_fmt Character vector of column names to exclude from the
#'   `#,##0` number format.
#' @param detect_years If `TRUE` (default), numeric columns where every
#'   non-`NA` value is a whole number between 1800 and 2200 are excluded
#'   from the `#,##0` number format.
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
#' # Insert as Excel table
#' write_excel(mtcars, "out.xlsx", as_table = TRUE)
#'
#' # Exclude a column from the number format
#' write_excel(df, "out.xlsx", skip_fmt = "periode")
#' }
#'
#' @seealso [daos::append_excel()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang %||%
#' @export
write_excel <- function(
    data,
    path,
    overwrite     = FALSE,
    as_table      = FALSE,
    freeze_header = TRUE,
    skip_fmt      = NULL,
    detect_years  = TRUE
) {
  .xl_check_available()
  .xl_check_path(path)

  data_list <- .xl_as_list(data, "data")

  if (file.exists(path) && !overwrite)
    cli::cli_abort(c(
      "File {.path {path}} already exists.",
      "i" = "Set {.code overwrite = TRUE} to replace it, or use {.fun append_excel} to add sheets."
    ))

  wb <- openxlsx2::wb_workbook()
  for (nm in names(data_list)) {
    wb <- .xl_add_sheet(wb, nm, data_list[[nm]], as_table, freeze_header,
                        skip_fmt, detect_years)
  }

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
  invisible(path)
}

#' Append sheets to an existing Excel file
#'
#' Adds one or more sheets to an existing `.xlsx` workbook without touching
#' its other sheets. New sheets get the same formatting as
#' [daos::write_excel()]: bold frozen header, blank `NA` cells, and `#,##0`
#' number format for large numeric columns (with automatic exclusion of
#' year-like columns).
#'
#' @inheritParams write_excel
#' @param data A data frame or named list of data frames to add as new
#'   sheets. Same naming defaults as in [daos::write_excel()].
#' @param path Path to an existing `.xlsx` file.
#' @param overwrite If `FALSE` (default), aborts when a sheet of the same name
#'   already exists in the workbook. Set to `TRUE` to replace it.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' write_excel(list(Hoved = mtcars), "out.xlsx")
#' append_excel(list(Bilag = iris), "out.xlsx")
#' }
#'
#' @seealso [daos::write_excel()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang %||%
#' @export
append_excel <- function(
    data,
    path,
    overwrite     = FALSE,
    as_table      = FALSE,
    freeze_header = TRUE,
    skip_fmt      = NULL,
    detect_years  = TRUE
) {
  .xl_check_available()
  .xl_check_path(path)

  data_list <- .xl_as_list(data, "data")

  if (!file.exists(path))
    cli::cli_abort(c(
      "File {.path {path}} does not exist.",
      "i" = "Use {.fun write_excel} to create a new file."
    ))

  wb <- openxlsx2::wb_load(path)
  for (nm in names(data_list)) {
    if (nm %in% wb$sheet_names) {
      if (!overwrite)
        cli::cli_abort(c(
          "Sheet {.val {nm}} already exists in {.path {path}}.",
          "i" = "Set {.code overwrite = TRUE} to replace it."
        ))
      wb <- openxlsx2::wb_remove_worksheet(wb, sheet = nm)
    }
    wb <- .xl_add_sheet(wb, nm, data_list[[nm]], as_table, freeze_header,
                        skip_fmt, detect_years)
  }

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
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
  nms <- names(x) %||% character(length(x))
  nms[nms == ""] <- paste0("Sheet", which(nms == ""))
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
                          skip_fmt, detect_years) {
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
    wb <- openxlsx2::wb_add_data_table(wb, sheet_name, df)
  } else {
    wb <- openxlsx2::wb_add_data(wb, sheet_name, df)
    wb <- openxlsx2::wb_add_font(
      wb, sheet_name,
      bold = TRUE,
      dims = openxlsx2::wb_dims(rows = 1, cols = seq_len(ncols))
    )
  }

  if (freeze_header)
    wb <- openxlsx2::wb_freeze_pane(wb, sheet_name, first_row = TRUE)

  if (nrows > 0) {
    num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    num_cols <- num_cols[vapply(num_cols, function(col) {
      max(abs(df[[col]]), na.rm = TRUE) >= 1000
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
        numfmt = "#,##0"
      )
    }
  }

  wb
}
