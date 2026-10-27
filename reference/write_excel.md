# Write data frames to a presentable Excel file

Writes an `.xlsx` workbook with formatting applied: the header row is
bold and frozen, `NA` values are shown as blank cells, and numeric
columns are formatted with a thousand separator and `digits` displayed
decimals (default zero) when the column contains at least one absolute
value \>= 1000. Underlying values are preserved. Only the display format
changes.

## Usage

``` r
write_excel(
  data,
  path,
  mode = c("new", "append", "replace", "overwrite"),
  as_table = FALSE,
  freeze_header = TRUE,
  skip_fmt = NULL,
  detect_years = TRUE,
  digits = 0
)
```

## Arguments

- data:

  A data frame or named list of data frames. A single data frame
  defaults to sheet name `"Sheet1"`; unnamed list elements get names
  `"Sheet1"`, `"Sheet2"`, etc. Sheet names must be valid Excel names and
  unique ignoring case.

- path:

  Path to the output `.xlsx` file.

- mode:

  One of `"new"` (default: create a file; fail if it exists), `"append"`
  (add sheets to an existing file; fail on name collisions), `"replace"`
  (replace matching sheets and add new ones in an existing file), or
  `"overwrite"` (write a fresh workbook, replacing the entire file if
  present). Replaced sheets retain their position; new sheets go at the
  end. Append and replace operate on whole sheets, not individual rows.

- as_table:

  If `TRUE`, data is inserted as an Excel ListObject (table with filter
  arrows and banded rows). Default `FALSE`.

- freeze_header:

  If `TRUE` (default), freezes the first row.

- skip_fmt:

  Character vector of column names to exclude from the automatic number
  format.

- detect_years:

  If `TRUE` (default), numeric columns where every non-`NA` value is a
  whole number between 1800 and 2200 are excluded from the automatic
  number format.

- digits:

  Number of displayed decimal places for automatically formatted numeric
  columns (0 to 15; default 0). Use `NULL` to disable automatic numeric
  formatting. Stored values are never rounded. Small-number columns,
  detected year columns and `skip_fmt` columns retain their default
  format.

## Value

`path`, invisibly.

## Details

Year-like columns are excluded from the number format automatically: a
numeric column where every non-`NA` value is a whole number between 1800
and 2200 is assumed to hold years, so `2020` is not displayed as
`2.020`. Set `detect_years = FALSE` to disable the heuristic, and use
`skip_fmt` for columns it cannot guess (e.g. numeric period codes like
`202001`).

Only the modern `.xlsx` format is supported. The old binary `.xls`
format cannot be written.

Use `mode` to create a file, append sheets, replace selected sheets, or
overwrite the entire workbook. Sheet names are matched ignoring case.

## Examples

``` r
if (FALSE) { # \dontrun{
# New file with one sheet
write_excel(mtcars, "out.xlsx")

# New file with multiple sheets
write_excel(list(Cars = mtcars, Iris = iris), "out.xlsx")

# Add or replace sheets in an existing file
write_excel(list(Bilag = iris), "out.xlsx", mode = "append")
write_excel(list(Cars = mtcars), "out.xlsx", mode = "replace")

# Replace the entire workbook
write_excel(mtcars, "out.xlsx", mode = "overwrite")

# Insert as Excel table
write_excel(mtcars, "out.xlsx", as_table = TRUE)

# Exclude a column from the number format
write_excel(df, "out.xlsx", skip_fmt = "periode")
write_excel(df, "out.xlsx", digits = 2)
write_excel(df, "out.xlsx", digits = NULL)
} # }
```
