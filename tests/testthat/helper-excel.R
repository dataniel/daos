# A workbook laid out like a published table: a title, a defined table, a
# source note below and a comment to the right, plus a clean second sheet.
make_report_xlsx <- function(path) {
  openxlsx2::wb_workbook()$
    add_worksheet("Report")$
    add_data(x = "Table 3: Employed 2024", dims = "A1")$
    add_data_table(x = data.frame(a = 1:3, b = c("x", "y", "z")), dims = "B3", table_name = "Sales")$
    add_data(x = "Source: DST", dims = "B9")$
    add_data(x = "note", dims = "F4")$
    add_worksheet("Clean")$
    add_data(x = data.frame(q = 1:2))$
    save(path)
  path
}
