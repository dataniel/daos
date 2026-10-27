# Look up Danish industry labels for DB07 or DB25 codes

Returns the Danish titles from Statistics Denmark's bundled
classification tables. Supports full six-digit industry codes, two-,
three-, and four-digit hierarchy codes, and uppercase section letters
such as `"A"`. Dots and whitespace are removed automatically, including
mixed input.

## Usage

``` r
db_label(x, version)
```

## Source

[Statistics Denmark: DB25 and conversion
tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende),
sheets `3. DB25 Alle koder` and `4. DB07 Alle koder` in the branch key.
Source page updated 26 February 2026; downloaded 24 October 2026.

## Arguments

- x:

  A vector of industry codes, coerced to character if needed.

- version:

  Required classification: `"DB25"` or `"DB07"`.

## Value

A character vector of Danish labels in the same order and with the same
length as `x`.

## Details

Always choose `version = "DB07"` or `version = "DB25"` explicitly.
Identical codes can have different meanings in the two classifications.
This function looks up labels, it does not convert between
classifications. Unknown or malformed codes return `NA` with a warning.
Missing input stays missing without a warning. Leading zeroes are never
guessed, so keep codes as character data. No internet connection is
needed.

## See also

[`format_db07()`](https://dataniel.github.io/daos/reference/format_db07.md),
[`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md),
[`convert_db25_to_db07()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)

## Examples

``` r
db_label(c("011200", "01.12.00", NA), version = "DB25")
#> [1] "Dyrkning af ris" "Dyrkning af ris" NA               
db_label("01.49.10", version = "DB07")
#> [1] "Kenneler"
db_label(c("A", "01", "01.1", "01.11"), version = "DB25")
#> [1] "LANDBRUG, JAGT, SKOVBRUG OG FISKERI"                              
#> [2] "Plante- og husdyravl, jagt og serviceydelser i forbindelse hermed"
#> [3] "Dyrkning af etårige afgrøder"                                     
#> [4] "Dyrkning af korn (undtagen ris), bælgfrugter og olieholdige frø"  
# df |> dplyr::mutate(branche_label = db_label(dbkode, version = "DB07"))
```
