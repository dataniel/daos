# Write data frames to a presentable Excel file

Creates a new `.xlsx` workbook with formatting applied: the header row
is bold and frozen, `NA` values are shown as blank cells, and numeric
columns are formatted with a thousand separator and no displayed
decimals (`#,##0`) when the column contains at least one value \>= 1000.
Underlying values are preserved. Only the display format changes.

## Usage

``` r
write_excel(
  data,
  path,
  overwrite = FALSE,
  as_table = FALSE,
  freeze_header = TRUE,
  skip_fmt = NULL,
  detect_years = TRUE
)
```

## Arguments

- data:

  A data frame or named list of data frames. A single data frame
  defaults to sheet name `"Sheet1"`; unnamed list elements get names
  `"Sheet1"`, `"Sheet2"`, etc.

- path:

  Path to the output `.xlsx` file.

- overwrite:

  If `FALSE` (default), aborts when `path` already exists. Set to `TRUE`
  to replace the file.

- as_table:

  If `TRUE`, data is inserted as an Excel ListObject (table with filter
  arrows and banded rows). Default `FALSE`.

- freeze_header:

  If `TRUE` (default), freezes the first row.

- skip_fmt:

  Character vector of column names to exclude from the `#,##0` number
  format.

- detect_years:

  If `TRUE` (default), numeric columns where every non-`NA` value is a
  whole number between 1800 and 2200 are excluded from the `#,##0`
  number format.

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

Use
[`append_excel()`](https://dataniel.github.io/daos/reference/append_excel.md)
to add sheets to an existing file.

## See also

[`append_excel()`](https://dataniel.github.io/daos/reference/append_excel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# New file with one sheet
write_excel(mtcars, "out.xlsx")

# New file with multiple sheets
write_excel(list(Cars = mtcars, Iris = iris), "out.xlsx")

# Insert as Excel table
write_excel(mtcars, "out.xlsx", as_table = TRUE)

# Exclude a column from the number format
write_excel(df, "out.xlsx", skip_fmt = "periode")
} # }
```
