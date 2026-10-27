#' Read the sheets or tables of an Excel workbook
#'
#' Reads every sheet of a workbook into a named list, finding the table on
#' each sheet, or the sheets, ranges or defined Excel tables you choose. Warns
#' when cells outside what was read are left behind.
#'
#' @details
#' **Sheets.** With `sheet = NULL` (default), every sheet is read and the
#' result is a list named by sheet. Name or number the sheets to read only
#' those.
#'
#' **Finding the table.** Without a range, `readxl` reads the smallest
#' rectangle around *all* non-empty cells, so a title becomes the header, a
#' note below the table becomes extra rows, and a comment to the right
#' becomes a column named `...7`. `read_workbook()` instead finds the table
#' on each sheet, the largest block of cells not split by an entirely empty
#' row or column, with title rows on top left out (see [inspect_excel()]),
#' and reads only that. Whatever lies outside is not read, and a warning
#' lists it, except titles above the table, which are expected.
#'
#' **Speed.** Everything is read by `readxl`'s C++ reader: each sheet once as
#' text to find the table, and once more for the table itself with proper
#' column types. That is about twice a plain `readxl::read_excel()`, for
#' `.xlsx` and `.xls` alike. Give `range` and `check = FALSE` to read with a
#' single call.
#'
#' **Passwords.** A workbook with a password to open is encrypted, and
#' `readxl` cannot read it; `read_workbook()` says so instead of failing with
#' a zip error. Sheet or workbook protection without a password to open does
#' not encrypt the file and reads as usual.
#'
#' **Choosing the area yourself.** `range` takes one range for one sheet, or
#' a named vector with one range per sheet, where `NA` (or leaving a sheet
#' out) means find the table. `table` reads defined Excel tables (Insert >
#' Table) by name, or all of them with `table = TRUE`. A table keeps its
#' range when rows are added in Excel, which a hard-coded `range` does not,
#' so prefer it when the workbook has one. A table's totals row is not read.
#' `readxl` has no support for tables; their ranges are looked up in the file
#' and read as ranges.
#'
#' @inheritParams inspect_excel
#' @param path Path to an Excel file (`.xlsx`, `.xlsm` or `.xls`).
#' @param sheet Sheet names or positions. `NULL` (default) reads every sheet.
#' @param table Names of defined Excel tables, or `TRUE` for all of them.
#'   Cannot be combined with `sheet` or `range`. `.xlsx` and `.xlsm` only.
#' @param check If `TRUE` (default), warn about cells outside what was read.
#' @param ... Passed on to `readxl::read_excel()`, such as `col_types`, `na`
#'   or `skip`. `skip` is applied before the table is found.
#'
#' @return A tibble when a single sheet, range or table is named; otherwise
#'   a named list of tibbles, also when the workbook has only one sheet, so
#'   the shape depends on the call and not on the file.
#'
#' @examples
#' \dontrun{
#' # Every sheet, the table found on each, as a named list:
#' sheets <- read_workbook("data/report.xlsx")
#'
#' # One sheet, as a tibble:
#' df <- read_workbook("data/report.xlsx", sheet = "2024")
#'
#' # Your own range, for one sheet or per sheet (NA: find it):
#' df     <- read_workbook("data/report.xlsx", range = "2024!B3:F40")
#' sheets <- read_workbook("data/report.xlsx", range = c(`2024` = "B3:F40", `2023` = NA))
#'
#' # A defined table, or all of them:
#' sales  <- read_workbook("data/report.xlsx", table = "Sales")
#' tables <- read_workbook("data/report.xlsx", table = TRUE)
#' }
#'
#' @seealso [daos::inspect_excel()] for the check on its own,
#'   [daos::read_files()] to read many files at once.
#' @export
read_workbook <- function(path, sheet = NULL, range = NULL, table = NULL,
                          check = TRUE, ...) {
  .excel_check_path(path)
  skip <- list(...)$skip %||% 0
  plan <- .excel_plan(path, sheet, range, table)
  plan <- .excel_detect(path, plan, skip)

  result <- lapply(seq_len(nrow(plan)), function(i) {
    if (is.na(plan$range[i])) {
      readxl::read_excel(path, sheet = plan$sheet[i], ...)
    } else {
      # Pass the range as cell_limits: readxl parses range strings with
      # cellranger, which rejects rows from 100000 up ("A1:J100001").
      # readxl ignores skip with a range; drop it so the call is unambiguous.
      rect <- .range_rect(plan$range[i])
      limits <- readxl::cell_limits(c(rect$r1, rect$c1), c(rect$r2, rect$c2))
      args <- list(...)
      args$skip <- NULL
      do.call(readxl::read_excel, c(list(path, sheet = plan$sheet[i], range = limits), args))
    }
  })
  names(result) <- plan$name

  if (check) .excel_warn_outside(path, plan)

  if (attr(plan, "single")) result[[1]] else result
}

.excel_warn_outside <- function(path, plan) {
  found <- .excel_inspect(path, plan)
  # A title above the table is not read, and expected
  found <- found[found$position != "title", ]
  if (nrow(found) == 0) return(invisible())

  where <- ifelse(grepl("left|right", found$position), paste(found$position, "of"), found$position)
  first <- ifelse(nchar(found$first) > 30, paste0(substr(found$first, 1, 29), "…"), found$first)
  bullets <- paste0(found$sheet, ": ", found$block, " ", where, " ", found$area, ' ("', first, '")')
  n_sheets <- length(unique(found$sheet))
  detected <- intersect(found$sheet, plan$sheet[plan$detected])

  cli::cli_warn(c(
    "{.file {basename(path)}}: cells outside the area read on {n_sheets} sheet{?s} were not read:",
    cap_bullets(bullets, bullet = "*"),
    "i" = if (length(detected) > 0) "The table on {.val {detected}} was found automatically. To read another area, give {.arg range}, e.g. {.code range = c(Sheet1 = \"B3:F40\")}.",
    "i" = "{.fun daos::inspect_excel} lists the blocks as a tibble."
  ))
}
