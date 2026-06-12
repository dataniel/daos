# Download a table from the Greenland Statbank

Fetches data for a table and returns it as a tibble in long format: one
column per variable and a `value` column with the numbers.

## Usage

``` r
statbank_get(
  table,
  ...,
  lang = "da",
  .col_names = c("text", "code"),
  .values = c("text", "code"),
  .type_convert = TRUE
)
```

## Arguments

- table:

  The table's path in the tree, e.g. `"BE/BE01/BEXSAT1.PX"`. A bare
  table id (e.g. `"BEXSAT1.PX"`) also works once the table list has been
  fetched with
  [`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md)
  or
  [`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md)
  in the same session.

- ...:

  Named selections, one per variable. Values can be value codes, value
  texts, or `"*"` for all.

- lang:

  Language of titles and labels: `"da"` (default), `"en"`, or `"kl"`.

- .col_names:

  `"text"` (default) names the columns by the variables' display texts;
  `"code"` uses the variable codes.

- .values:

  `"text"` (default) fills the cells with value display texts; `"code"`
  uses the value codes.

- .type_convert:

  If `TRUE` (default), the result is passed through
  [`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html),
  so e.g. a year column comes back numeric. Set to `FALSE` to keep every
  variable column as character.

## Value

A tibble with one column per variable and a `value` column. The table's
footnotes and provenance ride along as attributes: `attr(df, "notes")`,
`attr(df, "source")`, `attr(df, "updated")`, and `attr(df, "contact")`.

## Details

Selections are passed as named arguments. Names are matched against the
variable codes *and* their display texts, and values against both value
codes and value texts, so
`statbank_get("BE/BE01/BEXSAT1.PX", tid = 2024, art = "Antal")` works
without knowing the internal codes. Matching ignores case and folds
Danish letters (`foedested` matches `fødested`). Use `"*"` to select all
values; variables that are not mentioned default to all values.

By default, columns are named by the variables' display texts in the
chosen language, and cells hold the display texts of the values. Set
`.col_names = "code"` and/or `.values = "code"` to get the internal
codes instead, e.g. when a coded column (such as sex as 0/1) is wanted
for joins or modelling. The option arguments are dot-prefixed so they
can never collide with a variable name in `...`.

## See also

[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md),
[`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md),
[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)

## Examples

``` r
if (FALSE) { # \dontrun{
df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = c(2023, 2024, 2025),
  art = "Antal"
)
attr(df, "notes")

# Codes instead of display texts, no type conversion:
df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = 2024,
  .col_names = "code",
  .values = "code",
  .type_convert = FALSE
)
} # }
```
