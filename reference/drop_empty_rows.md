# Drop rows or columns that are empty in selected columns

`drop_empty_rows()` removes a row only when every selected column is
missing in that row. Other columns, such as identifiers, are kept but do
not influence the decision. `drop_empty_cols()` removes only selected
columns that are entirely missing.

## Usage

``` r
drop_empty_rows(data, ..., blank = FALSE)

drop_empty_cols(data, ..., blank = FALSE)
```

## Arguments

- data:

  A data frame or tibble.

- ...:

  Columns to inspect, using tidyselect syntax: bare names, ranges,
  `starts_with()`, `where(is.numeric)`, or `all_of(names)`. With no
  selection, all columns are inspected. Columns cannot be renamed.

- blank:

  Also consider empty strings and whitespace-only strings empty? Default
  `FALSE`. Applies to character and factor columns; retained values are
  never trimmed or changed. Zero and `FALSE` are not empty.

## Value

The input data with empty rows or selected empty columns removed.

## Details

Missingness follows [`is.na()`](https://rdrr.io/r/base/NA.html),
including `NaN`. With `blank = TRUE`, whitespace includes spaces, tabs,
line breaks, and Unicode separators. List columns use
[`is.na()`](https://rdrr.io/r/base/NA.html) on each list element; their
contents are not recursively inspected. Matrix and data-frame columns
must be excluded from the selection.

An empty selection returns the input unchanged. An input with zero rows
keeps its columns, preserving its schema. An input with zero columns
keeps its rows. Both functions preserve column types and row order.
Decisions use the entire input, including for grouped data. Remaining
grouping columns are preserved; removing a grouping column updates the
grouping metadata.

To remove both empty rows and empty columns, call `drop_empty_rows()`
followed by `drop_empty_cols()`.

## Examples

``` r
df <- tibble::tibble(
  id = 1:3,
  score_a = c(1, NA, NA),
  score_b = c(NA_real_, NA_real_, NA_real_),
  comment = c("ok", "", "  ")
)
drop_empty_rows(df, starts_with("score_"))
#> # A tibble: 1 × 4
#>      id score_a score_b comment
#>   <int>   <dbl>   <dbl> <chr>  
#> 1     1       1      NA ok     
drop_empty_rows(df, comment, blank = TRUE)
#> # A tibble: 1 × 4
#>      id score_a score_b comment
#>   <int>   <dbl>   <dbl> <chr>  
#> 1     1       1      NA ok     
drop_empty_cols(df, where(is.numeric))
#> # A tibble: 3 × 3
#>      id score_a comment
#>   <int>   <dbl> <chr>  
#> 1     1       1 "ok"   
#> 2     2      NA ""     
#> 3     3      NA "  "   
df |> drop_empty_rows(starts_with("score_")) |> drop_empty_cols()
#> # A tibble: 1 × 3
#>      id score_a comment
#>   <int>   <dbl> <chr>  
#> 1     1       1 ok     
```
