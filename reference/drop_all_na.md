# Drop all-`NA` rows and/or columns

Removes rows and/or columns that are entirely `NA` – handy for tidying
up data after a join or import has left empty rows or unused columns
behind. Unlike
[`tidyr::drop_na()`](https://tidyr.tidyverse.org/reference/drop_na.html),
which drops a row as soon as it contains a single `NA`, this only drops
rows (or columns) where *every* value is `NA`.

Equivalent to `janitor::remove_empty(which = which, cutoff = 1)`,
reimplemented here to keep the dependency footprint small.

## Usage

``` r
drop_all_na(data, which = c("rows", "cols"))
```

## Arguments

- data:

  A data frame or tibble.

- which:

  Which dimension(s) to clean: `"rows"`, `"cols"`, or both (the
  default). Partial matching is allowed.

## Value

`data` with fully-`NA` rows and/or columns removed. The class of the
input (data frame or tibble) is preserved.

## Examples

``` r
df <- tibble::tibble(
  a = c(1, NA, 3),
  b = c(NA, NA, NA),
  c = c("x", NA, "z")
)

drop_all_na(df)                  # drops column b and the all-NA row
#> # A tibble: 2 × 2
#>       a c    
#>   <dbl> <chr>
#> 1     1 x    
#> 2     3 z    
drop_all_na(df, which = "rows")  # only the all-NA row
#> # A tibble: 2 × 3
#>       a b     c    
#>   <dbl> <lgl> <chr>
#> 1     1 NA    x    
#> 2     3 NA    z    
drop_all_na(df, which = "cols")  # only column b
#> # A tibble: 3 × 2
#>       a c    
#>   <dbl> <chr>
#> 1     1 x    
#> 2    NA NA   
#> 3     3 z    
```
