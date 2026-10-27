# Inspect possible classifications of mixed DB07 and DB25 industry codes

Checks full six-digit industry codes against both bundled DST keys
without assigning a classification to codes present in both. Dots and
whitespace are removed automatically. Leading zeroes are not guessed.

## Usage

``` r
inspect_db(x)
```

## Source

[Statistics Denmark: DB25 and conversion
tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende).
Uses the same bundled tables as
[`db_label()`](https://dataniel.github.io/daos/reference/db_label.md)
and
[`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md).

## Arguments

- x:

  A vector of full industry codes, coerced to character if needed.

## Value

A tibble with one row per input, preserving order and duplicates:
`input` (original value as character), `code` (compact code), `status`
(`"db07_only"`, `"db25_only"`, `"both"`, `"unknown"`, or `"missing"`),
and `label_db07` and `label_db25`. Unknown includes malformed values and
aggregated codes. Missing labels are `NA`. Diagnostic statuses are
returned without warnings.

## Details

A code shared by DB07 and DB25 may have different meanings in each
version. Even identical labels do not establish identical definitions.
Use source classification metadata, the original industry text and its
time context to investigate shared codes before labelling or converting
them. This function neither converts codes nor changes the explicit
version requirement of
[`db_label()`](https://dataniel.github.io/daos/reference/db_label.md).
It supports full industry codes only.

## See also

[`db_label()`](https://dataniel.github.io/daos/reference/db_label.md),
[`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md),
[`convert_db25_to_db07()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)

## Examples

``` r
inspect_db(c("01.49.10", "014800", "25.30.00", "011200", "999999", NA))
#> # A tibble: 6 × 5
#>   input    code   status    label_db07                                label_db25
#>   <chr>    <chr>  <chr>     <chr>                                     <chr>     
#> 1 01.49.10 014910 db07_only Kenneler                                  NA        
#> 2 014800   014800 db25_only NA                                        Avl af an…
#> 3 25.30.00 253000 both      Fremstilling af dampkedler undtagen cent… Fremstill…
#> 4 011200   011200 both      Dyrkning af ris                           Dyrkning …
#> 5 999999   999999 unknown   NA                                        NA        
#> 6 NA       NA     missing   NA                                        NA        
# dplyr::bind_cols(df, inspect_db(df$dbkode))
```
