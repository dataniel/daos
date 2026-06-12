# Append sheets to an existing Excel file

Adds one or more sheets to an existing `.xlsx` workbook without touching
its other sheets. New sheets get the same formatting as
[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md):
bold frozen header, blank `NA` cells, and `#,##0` number format for
large numeric columns (with automatic exclusion of year-like columns).

## Usage

``` r
append_excel(
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

  A data frame or named list of data frames to add as new sheets. Same
  naming defaults as in
  [`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md).

- path:

  Path to an existing `.xlsx` file.

- overwrite:

  If `FALSE` (default), aborts when a sheet of the same name already
  exists in the workbook. Set to `TRUE` to replace it.

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

## See also

[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
write_excel(list(Hoved = mtcars), "out.xlsx")
append_excel(list(Bilag = iris), "out.xlsx")
} # }
```
