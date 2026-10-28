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

# Named ranges: two workbook-wide names on "Data", and "Local" defined on
# both sheets with sheet scope.
make_named_xlsx <- function(path) {
  wb <- openxlsx2::wb_workbook()$
    add_worksheet("Data")$
    add_data(x = data.frame(a = 1:3, b = c("x", "y", "z")), dims = "B3")$
    add_data(x = data.frame(c = 4:5), dims = "E3")$
    add_worksheet("Other")$
    add_data(x = data.frame(q = 1:2))
  wb$add_named_region(sheet = "Data", dims = "B3:C6", name = "Sales")
  wb$add_named_region(sheet = "Data", dims = "E3:E5", name = "Costs")
  wb$add_named_region(sheet = "Other", dims = "A1:A3", name = "Local", local_sheet = TRUE)
  wb$add_named_region(sheet = "Data", dims = "E3:E5", name = "Local", local_sheet = TRUE)
  wb$save(path)
  path
}
