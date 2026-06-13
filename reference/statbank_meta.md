# Get the metadata for a statbank table

Fetches a table's title and variables: codes, display texts, and the
values each variable can take.

## Usage

``` r
statbank_meta(table, lang = NULL, bank = "gl")
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

- lang:

  Language of titles and labels, or `NULL` (default) for the bank's own
  default. Greenland offers `"da"`, `"kl"`, `"en"`; the Faroe Islands
  offer `"fo"`, `"en"`.

- bank:

  Which statbank: `"gl"` (Greenland, the default) or `"fo"` (the Faroe
  Islands).

## Value

A list with `title`, `path`, and `variables`, where `variables` is a
tibble with columns `code`, `text`, `values` (list), `valueTexts`
(list), `elimination`, and `time`.

## See also

[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)

## Examples

``` r
if (FALSE) { # \dontrun{
meta <- statbank_meta("BE/BE01/BEXSAT1.PX")
meta$variables
} # }
```
