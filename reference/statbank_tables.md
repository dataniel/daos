# List every table in a statbank

Walks the whole table tree once and returns all tables with their paths
and titles. The walk takes a number of small requests (one per folder),
so the result is cached for the rest of the session; pass
`refresh = TRUE` to fetch it again.

## Usage

``` r
statbank_tables(lang = NULL, bank = "gl", refresh = FALSE)
```

## Arguments

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

- refresh:

  If `TRUE`, ignore the session cache and walk the tree again. Default
  `FALSE`.

## Value

A tibble with columns `id`, `title`, `path` (the folder the table sits
in), and `updated`.

## See also

[`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md),
[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tables <- statbank_tables()
} # }
```
