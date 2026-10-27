# read_workbook() warns once about the cells it left behind

    Code
      res <- read_workbook("report.xlsx")
    Condition
      Warning:
      'report.xlsx': cells outside the area read on 1 sheet were not read:
      * Report: F4 right of B3:C6 ("note")
      * Report: B9 below B3:C6 ("Source: DST")
      i The table on "Report" was found automatically. To read another area, give `range`, e.g. `range = c(Sheet1 = "B3:F40")`.
      i `daos::inspect_excel()` lists the blocks as a tibble.

# read_workbook() leaves a title above a range out of the warning

    Code
      res <- read_workbook("report.xlsx", range = "Report!B3:C6")
    Condition
      Warning:
      'report.xlsx': cells outside the area read on 1 sheet were not read:
      * Report: F4 right of B3:C6 ("note")
      * Report: B9 below B3:C6 ("Source: DST")
      i `daos::inspect_excel()` lists the blocks as a tibble.

# read_workbook() explains bad sheet, range and table arguments

    Code
      read_workbook("report.xlsx", sheet = "Nope")
    Condition
      Error in `read_workbook()`:
      ! 'report.xlsx' has no sheet named "Nope".
      i Sheets: "Report" and "Clean".

---

    Code
      read_workbook("report.xlsx", sheet = 5)
    Condition
      Error in `read_workbook()`:
      ! 'report.xlsx' has 2 sheets; there is no sheet 5.

---

    Code
      read_workbook("report.xlsx", range = "B3:C6")
    Condition
      Error in `read_workbook()`:
      ! `range` needs one sheet.
      i Give `sheet`, write the range as "Sheet1!B3:F40", or give one range per sheet: `range = c(Sheet1 = "B3:F40")`.

---

    Code
      read_workbook("report.xlsx", range = c("B3:C6", "A1:A2"))
    Condition
      Error in `read_workbook()`:
      ! Several ranges need the sheets they belong to.
      i Name them: `range = c(Sheet1 = "B3:F40", Sheet2 = "A1:D9")`.

---

    Code
      read_workbook("report.xlsx", range = c(Nope = "B3:C6"))
    Condition
      Error in `read_workbook()`:
      ! `range` names sheet "Nope", which is not read.
      i Sheets: "Report" and "Clean".

---

    Code
      read_workbook("report.xlsx", sheet = "Clean", range = c(Report = "B3:C6"))
    Condition
      Error in `read_workbook()`:
      ! `range` names sheet "Report", which is not read.
      i Add it to `sheet`.

---

    Code
      read_workbook("report.xlsx", range = c(Report = "B3-C6"))
    Condition
      Error in `read_workbook()`:
      ! "B3-C6" is not a cell range such as "B3:F40".

---

    Code
      read_workbook("report.xlsx", table = "Nope")
    Condition
      Error in `read_workbook()`:
      ! 'report.xlsx' has no table named "Nope".
      i Tables: "sales".

---

    Code
      read_workbook("report.xlsx", table = TRUE, sheet = 1)
    Condition
      Error in `read_workbook()`:
      ! Use `table` on its own.
      i A table already names its sheet and range.

---

    Code
      read_workbook("missing.xlsx")
    Condition
      Error in `read_workbook()`:
      ! File 'missing.xlsx' does not exist.

# read_workbook() recognises a password-protected workbook

    Code
      read_workbook("locked.xlsx")
    Condition
      Error in `read_workbook()`:
      ! 'locked.xlsx' is password-protected, or an '.xls' file named '.xlsx'.
      i readxl cannot read encrypted workbooks. Save a copy without the password to open, or rename it to '.xls' if it is an old Excel file.

