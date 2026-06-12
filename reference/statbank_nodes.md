# List one level of the Greenland Statbank table tree

Fetches the nodes directly under a path in the statbank's table tree.
The root holds the subject areas (population, labour market, prices, and
so on); each subject holds sub-folders and tables.

## Usage

``` r
statbank_nodes(path = "", lang = "da")
```

## Arguments

- path:

  Path within the tree, e.g. `""` (the root), `"BE"`, or `"BE/BE01"`.
  Use the `id` values from the previous level to drill down.

- lang:

  Language of titles and labels: `"da"` (default), `"en"`, or `"kl"`.

## Value

A tibble with columns `id`, `type` (`"l"` for folder, `"t"` for table),
`text`, and `updated` (tables only, `NA` for folders).

## References

Greenland Statbank, <https://bank.stat.gl>.

## See also

[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md),
[`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md),
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)

## Examples

``` r
if (FALSE) { # \dontrun{
statbank_nodes()          # subject areas
statbank_nodes("BE")      # folders under population
statbank_nodes("BE/BE01") # tables and folders under BE01
} # }
```
