# Convert industry codes between DB07 and DB25 using Statistics Denmark's keys

Converts full six-digit codes in either direction using a bundled copy
of Statistics Denmark's correspondence table (source page updated 26
February 2026, downloaded 24 October 2026). No network connection is
needed at runtime. Dots and whitespace are handled automatically,
including mixed input.

## Usage

``` r
convert_db07_to_db25(
  x,
  format = c("dotted", "compact"),
  method = c("strict", "simple")
)

convert_db25_to_db07(
  x,
  format = c("dotted", "compact"),
  method = c("strict", "simple")
)
```

## Source

[Statistics Denmark: DB25 and conversion
tables](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende).
The rebuild script `data-raw/db07_db25.R` records the source file URLs.

## Arguments

- x:

  A vector of full codes in the source classification, coerced to
  character if needed.

- format:

  Output format: `"dotted"` (default) or `"compact"`.

- method:

  `"strict"` (default) converts only codes with a single destination.
  `"simple"` uses DST's simplified conversion matrix.

## Value

A character vector of the same length and order as `x`.

## Details

`convert_db07_to_db25()` converts DB07 to DB25; `convert_db25_to_db07()`
converts DB25 to DB07. The input classification must be chosen
explicitly: the same code can occur in both classifications with
different meanings.

With `method = "strict"`, codes with multiple destinations return `NA`
with a warning. With `method = "simple"`, the destination is taken from
DST's separate simplified conversion matrix for the chosen direction.
The reverse conversion does not invert the forward simplified matrix.
This is an approximation: DST bases the choice on numbers of units, not
economic activity. It cannot establish the correct code for every
individual business or allocate turnover between split industries.

Input must contain exactly six digits after removing dots and whitespace
and must occur in the source classification's key. Invalid lengths,
unknown codes, and other characters return `NA` with a warning. Missing
input remains `NA` without a warning. Leading zeroes are never guessed;
keep codes as character data. Aggregated codes are not supported.

## See also

[`format_db07()`](https://dataniel.github.io/daos/reference/format_db07.md)

## Examples

``` r
convert_db07_to_db25(c("011100", "01.49.10", NA))
#> [1] "01.11.00" "01.48.00" NA        
convert_db07_to_db25("01.19.00", method = "simple", format = "compact")
#> [1] "011900"
convert_db25_to_db07("25.30.00", format = "compact")
#> [1] "254000"
# df |> dplyr::mutate(db25 = convert_db07_to_db25(db07))
```
