# Search statbank tables by title

Filters the full table list (see
[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md))
on a search string, matched case-insensitively against titles and table
ids. The first call walks the table tree; later calls use the session
cache.

## Usage

``` r
statbank_search(text, lang = NULL, bank = "gl", refresh = FALSE)
```

## Arguments

- text:

  Search string, interpreted as a regular expression.

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

A tibble with the matching rows from
[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md).

## See also

[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md),
[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md)

## Examples

``` r
if (FALSE) { # \dontrun{
statbank_search("befolkning")
statbank_search(" wages", bank = "fo")
} # }
```
