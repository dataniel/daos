# Compare column types across data frames

Shows the column types of one or more data frames side-by-side. Useful
for diagnosing type mismatches before a join or a call to
[`bind_files()`](https://dataniel.github.io/daos/reference/bind_files.md).

## Usage

``` r
view_types(..., diff = FALSE, focus = NULL)
```

## Arguments

- ...:

  Data frames to compare (unquoted). Names are inferred from the
  expressions passed.

- diff:

  Logical. If `TRUE`, only columns where types differ across datasets
  are shown. Default: `FALSE`.

- focus:

  A named length-1 character vector, e.g. `c(year = "int")`. When
  supplied, only the named column is shown, and only for datasets where
  the type does **not** match the expected type. Returns an empty tibble
  (0 rows) when all types match — suitable for use in tests.

## Value

A tibble with a `column` column and one column per input dataset showing
the
[`pillar::type_sum()`](https://pillar.r-lib.org/reference/type_sum.html)
type string.

## See also

[`bind_files()`](https://dataniel.github.io/daos/reference/bind_files.md)

## Examples

``` r
df1 <- data.frame(x = 1L, y = "a")
df2 <- data.frame(x = 1.0, y = "b")

view_types(df1, df2)
#> # A tibble: 2 × 3
#>   column df1   df2  
#>   <chr>  <chr> <chr>
#> 1 x      int   dbl  
#> 2 y      chr   chr  
view_types(df1, df2, diff = TRUE)
#> # A tibble: 1 × 3
#>   column df1   df2  
#>   <chr>  <chr> <chr>
#> 1 x      int   dbl  
view_types(df1, df2, focus = c(x = "int"))
#> # A tibble: 1 × 2
#>   column df2  
#>   <chr>  <chr>
#> 1 x      dbl  
```
