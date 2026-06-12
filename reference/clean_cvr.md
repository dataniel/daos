# Standardise CVR numbers

Cleans a vector of Danish CVR numbers to the canonical 8-digit form:
dashes and spaces are stripped (`"12 34 56 78"` -\> `"12345678"`), and a
leading `"DK"` VAT prefix is removed (`"DK12345678"` -\> `"12345678"`).

## Usage

``` r
clean_cvr(x)
```

## Arguments

- x:

  A character vector of CVR numbers. Numeric vectors are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html) first.

## Value

A character vector of the same length.

## Details

Unlike
[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md),
seven-digit values are *not* zero-padded: a lost leading zero cannot be
distinguished from a typo, and inventing a digit would let a malformed
number slip past downstream checks such as a `cvr %like% "^\\d{8}$"`
checkpoint. Values are returned cleaned but otherwise untouched, so
malformed numbers stay visibly malformed.

## See also

[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)

## Examples

``` r
clean_cvr(c("DK12345678", "12 34 56 78", "12345678", NA))
#> [1] "12345678" "12345678" "12345678" NA        

# Typical use: standardise the join key on both sides
# df  |> dplyr::mutate(cvr = clean_cvr(cvr))
```
