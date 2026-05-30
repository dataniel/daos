# Test whether a value is "blank"

Returns `TRUE` if `x` is `NULL`, has length 0, contains only `NA`
values, or (for character vectors) contains only empty strings. More
intuitive than
[`rlang::is_empty()`](https://rlang.r-lib.org/reference/is_empty.html)
in data-cleaning contexts.

## Usage

``` r
is_blank(x)
```

## Arguments

- x:

  Any R value.

## Value

A single `TRUE` or `FALSE`.

## See also

[`%??%`](https://dataniel.github.io/daos/reference/grapes-help-help-grapes.md)

## Examples

``` r
is_blank(NULL)        # TRUE
#> [1] TRUE
is_blank(NA)          # TRUE
#> [1] TRUE
is_blank("")          # TRUE
#> [1] TRUE
is_blank(c(NA, NA))   # TRUE
#> [1] TRUE
is_blank(0)           # FALSE
#> [1] FALSE
is_blank("text")      # FALSE
#> [1] FALSE

# Compare with rlang::is_empty():
# is_empty("") returns FALSE, is_blank("") returns TRUE
```
