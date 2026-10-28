# Flag duplicate rows

Prepends two columns to a data frame: `isdup` (logical, `TRUE` when the
row appears more than once) and `dupid` (integer group identifier, `0`
for unique rows). The duplicate groups are numbered `1, 2, ...` in the
order they first appear. The key columns are neither copied nor sorted:
rows are grouped in one linear pass, which keeps it fast on
full-population registers with a character key such as cpr.

## Usage

``` r
flag_duplicates(data, ...)
```

## Arguments

- data:

  A data frame or tibble.

- ...:

  Columns used to identify duplicates (tidy-select). If omitted, all
  columns are used.

## Value

A tibble with `isdup` and `dupid` prepended.

## See also

[`expectr::expect_unique()`](https://dataniel.github.io/expectr/reference/expect_unique.html)
to check a key,
[`expectr::expect_empty()`](https://dataniel.github.io/expectr/reference/expect_empty.html)

## Examples

``` r
# All columns
flag_duplicates(ggplot2::mpg)
#> # A tibble: 234 × 13
#>    isdup dupid manufacturer model      displ  year   cyl trans drv     cty   hwy
#>    <lgl> <int> <chr>        <chr>      <dbl> <int> <int> <chr> <chr> <int> <int>
#>  1 FALSE     0 audi         a4           1.8  1999     4 auto… f        18    29
#>  2 FALSE     0 audi         a4           1.8  1999     4 manu… f        21    29
#>  3 FALSE     0 audi         a4           2    2008     4 manu… f        20    31
#>  4 FALSE     0 audi         a4           2    2008     4 auto… f        21    30
#>  5 FALSE     0 audi         a4           2.8  1999     6 auto… f        16    26
#>  6 FALSE     0 audi         a4           2.8  1999     6 manu… f        18    26
#>  7 FALSE     0 audi         a4           3.1  2008     6 auto… f        18    27
#>  8 FALSE     0 audi         a4 quattro   1.8  1999     4 manu… 4        18    26
#>  9 FALSE     0 audi         a4 quattro   1.8  1999     4 auto… 4        16    25
#> 10 FALSE     0 audi         a4 quattro   2    2008     4 manu… 4        20    28
#> # ℹ 224 more rows
#> # ℹ 2 more variables: fl <chr>, class <chr>

# Specific columns
flag_duplicates(ggplot2::mpg, manufacturer, model, year)
#> # A tibble: 234 × 13
#>    isdup dupid manufacturer model      displ  year   cyl trans drv     cty   hwy
#>    <lgl> <int> <chr>        <chr>      <dbl> <int> <int> <chr> <chr> <int> <int>
#>  1 TRUE      1 audi         a4           1.8  1999     4 auto… f        18    29
#>  2 TRUE      1 audi         a4           1.8  1999     4 manu… f        21    29
#>  3 TRUE      2 audi         a4           2    2008     4 manu… f        20    31
#>  4 TRUE      2 audi         a4           2    2008     4 auto… f        21    30
#>  5 TRUE      1 audi         a4           2.8  1999     6 auto… f        16    26
#>  6 TRUE      1 audi         a4           2.8  1999     6 manu… f        18    26
#>  7 TRUE      2 audi         a4           3.1  2008     6 auto… f        18    27
#>  8 TRUE      3 audi         a4 quattro   1.8  1999     4 manu… 4        18    26
#>  9 TRUE      3 audi         a4 quattro   1.8  1999     4 auto… 4        16    25
#> 10 TRUE      4 audi         a4 quattro   2    2008     4 manu… 4        20    28
#> # ℹ 224 more rows
#> # ℹ 2 more variables: fl <chr>, class <chr>

# Combined with a checkpoint from expectr for a validation pipeline:
if (FALSE) { # \dontrun{
ggplot2::mpg |>
  flag_duplicates() |>
  dplyr::filter(isdup) |>
  expectr::expect_empty(warn_msg = "Duplicate rows found")
} # }
```
