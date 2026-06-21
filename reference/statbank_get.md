# Download a table from a statbank

Fetches data for a table and returns it as a tibble in long format: one
column per variable and a `value` column with the numbers.

## Usage

``` r
statbank_get(
  table,
  ...,
  lang = NULL,
  bank = "gl",
  .col_names = c("code", "text"),
  .values = c("code", "text", "both"),
  .clean_names = TRUE,
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
  texts, or `"*"` for all. Because the option arguments are
  dot-prefixed, a variable can never be shadowed by one of them.

- lang:

  Language of titles and labels, or `NULL` (default) for the bank's own
  default. Greenland offers `"da"`, `"kl"`, `"en"`; the Faroe Islands
  offer `"fo"`, `"en"`.

- bank:

  Which statbank: `"gl"` (Greenland, the default) or `"fo"` (the Faroe
  Islands). It may also be a full base URL (everything before the table
  path, with language and database node already in it, e.g.
  `"https://bank.stat.gl/api/v1/da/Greenland"`), to reach any PXWeb v1
  endpoint; `lang` is then ignored.

- .col_names:

  `"code"` (default) names the columns by the variable codes; `"text"`
  uses the variables' display texts.

- .values:

  `"code"` (default) fills the cells with value codes; `"text"` uses the
  value display texts; `"both"` keeps the codes and adds a
  `<column>_txt` column with the display texts next to each.

- .clean_names:

  If `TRUE` (default), column names are snake-cased (lower-case, Danish
  letters folded to ASCII, non-alphanumerics to `_`), so e.g. a
  `"place of birth"` code becomes `place_of_birth`. Set to `FALSE` to
  keep the raw codes or labels.

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

Built as a programming aid, the defaults favour codes: columns are named
by the variable codes (snake-cased via `.clean_names`) and cells hold
the value codes – the shape that joins and models cleanly. Set
`.col_names = "text"` and/or `.values = "text"` for the display texts in
the chosen language instead, or `.values = "both"` to get the codes
*and* a `<column>_txt` column with the labels alongside. The option
arguments are dot-prefixed so they can never collide with a variable
name in `...`.

## See also

[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md),
[`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md),
[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Default: coded columns and cells, snake-cased names.
df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = c(2023, 2024, 2025),
  art = "Antal"
)
attr(df, "notes")

# Codes with the display texts alongside (a <column>_txt per variable):
df <- statbank_get("BE/BE01/BEXSAT1.PX", tid = 2024, .values = "both")

# Display texts instead of codes, as in the previous default:
df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = 2024,
  .col_names = "text",
  .values = "text"
)

# Point at any PXWeb v1 endpoint by giving bank a full base URL:
df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = 2024,
  bank = "https://bank.stat.gl/api/v1/da/Greenland"
)
} # }
```
