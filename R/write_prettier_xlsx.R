#' Write data frames to an xlsx file
#'
#' Creates or updates an Excel workbook. `data` creates/overwrites the file;
#' `append` adds sheets to an existing file. All numeric columns are formatted
#' with a thousand separator and no displayed decimals (`#,##0`) when the
#' column contains at least one value >= 1000; underlying values are preserved. `NA` values are shown as blank cells. The header row
#' is bold, and the first row is frozen by default.
#'
#' @param data A data frame or named list of data frames. Creates a new file
#'   (overwrites if it already exists). A single data frame defaults to sheet
#'   name `"Sheet1"`; unnamed list elements get names `"Sheet1"`, `"Sheet2"`,
#'   etc.
#' @param path Path to the output `.xlsx` file.
#' @param append A data frame or named list of data frames to add as new sheets
#'   to an existing file. Same naming defaults as `data`. Requires that `path`
#'   exists.
#' @param overwrite If `FALSE` (default), aborts when a sheet supplied via
#'   `append` already exists in the workbook. Set to `TRUE` to replace it.
#' @param as_table If `TRUE`, data is inserted as an Excel ListObject (table
#'   with filter arrows and banded rows). Default `FALSE`.
#' @param freeze_header If `TRUE` (default), freezes the first row.
#' @param skip_fmt Character vector of column names to exclude from the
#'   `#,##0` number format.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' # New file with one sheet
#' write_prettier_xlsx(mtcars, "out.xlsx")
#'
#' # New file with multiple sheets
#' write_prettier_xlsx(list(Cars = mtcars, Iris = iris), "out.xlsx")
#'
#' # Append a sheet to an existing file
#' write_prettier_xlsx(append = list(Extra = airquality), path = "out.xlsx")
#'
#' # Create file and append in one call
#' write_prettier_xlsx(list(Hoved = mtcars), "out.xlsx", append = list(Bilag = iris))
#'
#' # Insert as Excel table
#' write_prettier_xlsx(mtcars, "out.xlsx", as_table = TRUE)
#' }
#'
#' @importFrom cli cli_abort
#' @importFrom rlang %||%
#' @export
write_prettier_xlsx <- function(
    data         = NULL,
    path,
    append       = NULL,
    overwrite    = FALSE,
    as_table     = FALSE,
    freeze_header = TRUE,
    skip_fmt     = NULL
) {
  if (!requireNamespace("openxlsx2", quietly = TRUE))
    cli::cli_abort("Package {.pkg openxlsx2} is required. Install with {.code install.packages('openxlsx2')}.")

  if (is.null(data) && is.null(append))
    cli::cli_abort("At least one of {.arg data} or {.arg append} must be provided.")

  data_list   <- .wpx_as_list(data,   "data")
  append_list <- .wpx_as_list(append, "append")

  if (!is.null(data_list) && !is.null(append_list)) {
    overlap <- intersect(names(data_list), names(append_list))
    if (length(overlap) > 0)
      cli::cli_abort("Sheet name{?s} {.val {overlap}} appear in both {.arg data} and {.arg append}.")
  }

  if (!is.null(data_list)) {
    if (file.exists(path) && !overwrite)
      cli::cli_abort(c(
        "File {.path {path}} already exists.",
        "i" = "Set {.code overwrite = TRUE} to replace it."
      ))
    wb <- openxlsx2::wb_workbook()
  } else {
    if (!file.exists(path))
      cli::cli_abort(c(
        "File {.path {path}} does not exist.",
        "i" = "Use {.arg data} to create a new file."
      ))
    wb <- openxlsx2::wb_load(path)
  }

  for (nm in names(data_list %||% list())) {
    wb <- .wpx_add_sheet(wb, nm, data_list[[nm]], as_table, freeze_header, skip_fmt)
  }

  for (nm in names(append_list %||% list())) {
    if (nm %in% wb$sheet_names) {
      if (!overwrite)
        cli::cli_abort(c(
          "Sheet {.val {nm}} already exists in {.path {path}}.",
          "i" = "Set {.code overwrite = TRUE} to replace it."
        ))
      wb <- openxlsx2::wb_remove_worksheet(wb, sheet = nm)
    }
    wb <- .wpx_add_sheet(wb, nm, append_list[[nm]], as_table, freeze_header, skip_fmt)
  }

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
  invisible(path)
}

.wpx_as_list <- function(x, arg_name) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) return(list(Sheet1 = x))
  if (!is.list(x))
    cli::cli_abort("{.arg {arg_name}} must be a data frame or named list of data frames.")
  nms <- names(x) %||% character(length(x))
  nms[nms == ""] <- paste0("Sheet", which(nms == ""))
  names(x) <- nms
  x
}

.wpx_add_sheet <- function(wb, sheet_name, df, as_table, freeze_header, skip_fmt) {
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
