# Write data frames to an xlsx file

Creates or updates an Excel workbook. `data` creates/overwrites the
file; `append` adds sheets to an existing file. All numeric columns are
formatted with a thousand separator and no displayed decimals (`#,##0`)
when the column contains at least one value \>= 1000; underlying values
are preserved. `NA` values are shown as blank cells. The header row is
bold, and the first row is frozen by default.

## Usage

``` r
write_pretty_xlsx(
  data = NULL,
  path,
  append = NULL,
  overwrite = FALSE,
  as_table = FALSE,
  freeze_header = TRUE,
  skip_fmt = NULL
)
```

## Arguments

- data:

  A data frame or named list of data frames. Creates a new file
  (overwrites if it already exists). A single data frame defaults to
  sheet name `"Sheet1"`; unnamed list elements get names `"Sheet1"`,
  `"Sheet2"`, etc.

- path:

  Path to the output `.xlsx` file.

- append:

  A data frame or named list of data frames to add as new sheets to an
  existing file. Same naming defaults as `data`. Requires that `path`
  exists.

- overwrite:

  If `FALSE` (default), aborts when a sheet supplied via `append`
  already exists in the workbook. Set to `TRUE` to replace it.

- as_table:

  If `TRUE`, data is inserted as an Excel ListObject (table with filter
  arrows and banded rows). Default `FALSE`.

- freeze_header:

  If `TRUE` (default), freezes the first row.

- skip_fmt:

  Character vector of column names to exclude from the `#,##0` number
  format.

## Value

`path`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
# New file with one sheet
write_pretty_xlsx(mtcars, "out.xlsx")

# New file with multiple sheets
write_pretty_xlsx(list(Cars = mtcars, Iris = iris), "out.xlsx")

# Append a sheet to an existing file
write_pretty_xlsx(append = list(Extra = airquality), path = "out.xlsx")

# Create file and append in one call
write_pretty_xlsx(list(Hoved = mtcars), "out.xlsx", append = list(Bilag = iris))

# Insert as Excel table
write_pretty_xlsx(mtcars, "out.xlsx", as_table = TRUE)
} # }
```
