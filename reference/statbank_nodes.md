# List one level of a statbank table tree

Fetches the nodes directly under a path in the statbank's table tree.
The root holds the subject areas (population, labour market, prices, and
so on); each subject holds sub-folders and tables.

## Usage

``` r
statbank_nodes(path = "", lang = NULL, bank = "gl")
```

## Arguments

- path:

  Path within the tree, e.g. `""` (the root), `"BE"`, or `"BE/BE01"`.
  Use the `id` values from the previous level to drill down.

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

## Value

A tibble with columns `id`, `type` (`"l"` for folder, `"t"` for table),
`text`, and `updated` (tables only, `NA` for folders).

## References

Greenland Statbank, <https://bank.stat.gl>; Statistics Faroe Islands,
<https://statbank.hagstova.fo>.

## See also

[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md),
[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md),
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)

## Examples

``` r
if (FALSE) { # \dontrun{
statbank_nodes()              # Greenland subject areas
statbank_nodes("BE")          # folders under population
statbank_nodes(bank = "fo")   # Faroese subject areas
} # }
```
