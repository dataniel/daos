# Regex matching with `NA` preservation

An infix operator equivalent to
[`grepl()`](https://rdrr.io/r/base/grep.html), but `NA` values in `x`
remain `NA` in the result instead of being coerced to `FALSE`.

## Usage

``` r
x %like% pattern
```

## Arguments

- x:

  A vector to search in.

- pattern:

  A regular expression (see
  [`regex`](https://rdrr.io/r/base/regex.html)).

## Value

A logical vector the same length as `x`.

## Examples

``` r
c("a1", "b2", NA, "c") %like% "\\d"
#> [1]  TRUE  TRUE    NA FALSE

# Use in dplyr pipelines:
if (requireNamespace("dplyr", quietly = TRUE)) {
  dplyr::filter(ggplot2::mpg, model %like% "\\d+")
}
#> # A tibble: 114 × 11
#>    manufacturer model      displ  year   cyl trans drv     cty   hwy fl    class
#>    <chr>        <chr>      <dbl> <int> <int> <chr> <chr> <int> <int> <chr> <chr>
#>  1 audi         a4           1.8  1999     4 auto… f        18    29 p     comp…
#>  2 audi         a4           1.8  1999     4 manu… f        21    29 p     comp…
#>  3 audi         a4           2    2008     4 manu… f        20    31 p     comp…
#>  4 audi         a4           2    2008     4 auto… f        21    30 p     comp…
#>  5 audi         a4           2.8  1999     6 auto… f        16    26 p     comp…
#>  6 audi         a4           2.8  1999     6 manu… f        18    26 p     comp…
#>  7 audi         a4           3.1  2008     6 auto… f        18    27 p     comp…
#>  8 audi         a4 quattro   1.8  1999     4 manu… 4        18    26 p     comp…
#>  9 audi         a4 quattro   1.8  1999     4 auto… 4        16    25 p     comp…
#> 10 audi         a4 quattro   2    2008     4 manu… 4        20    28 p     comp…
#> # ℹ 104 more rows
```
