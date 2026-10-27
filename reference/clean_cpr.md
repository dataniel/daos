# Standardise CPR numbers

Cleans a vector of Danish CPR numbers to the canonical 10-digit form:
dashes and spaces are stripped, and nine-digit values consisting only of
digits are zero-padded on the left. The padding is well-founded: birth
days 01-09 mean that roughly a third of all CPR numbers legitimately
start with a zero, which Excel silently drops from numeric cells.

## Usage

``` r
clean_cpr(x)
```

## Arguments

- x:

  A character vector of CPR numbers. Numeric vectors are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html) first.

## Value

A character vector of the same length.

## Details

This is standardisation only, not validation. Values that cannot be
brought to 10 digits are returned cleaned but otherwise untouched, so a
malformed number stays visibly malformed for downstream checks. Use
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
for validity, or pipe through a checkpoint from expectr (see
[`vignette("expectr", package = "expectr")`](https://dataniel.github.io/expectr/articles/expectr.html)).

[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
applies this cleaning internally for its calculations, while preserving
the original CPR column in its output. Both functions use the same
native normalisation rules. Cleaning is optional before
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md);
use it when you need a standardised identifier for joins or export.
Already clean character vectors are returned without allocating a
replacement vector.

## See also

[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md),
[`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md)

## Examples

``` r
clean_cpr(c("111111-1118", "1111111118", "101004007", NA))
#> [1] "1111111118" "1111111118" "0101004007" NA          

# Typical use: standardise the join key on both sides
# df  |> dplyr::mutate(pnr = clean_cpr(pnr))
```
