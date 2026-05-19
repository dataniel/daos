# Row-bind a list of data frames

Combines a list of data frames into a single tibble using
[`purrr::list_rbind()`](https://purrr.tidyverse.org/reference/list_c.html).
When column types differ across files, an informative error is raised
with hints for resolution. Setting `.guess = TRUE` converts all columns
to character first, then lets
[`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html)
infer a common type.

## Usage

``` r
bind_files(data, .id = "source", .guess = FALSE)
```

## Arguments

- data:

  A list of data frames or tibbles.

- .id:

  Name of the source column added to identify which data frame each row
  originated from. Default is `"source"`.

- .guess:

  If `TRUE`, all columns are coerced to character before binding and
  then re-typed automatically. Use when column types differ across
  files. Default is `FALSE`.

## Value

A single tibble with all rows combined and a `source` column (or
whatever `.id` names it).

## See also

[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
to inspect type differences before binding

## Examples

``` r
df1 <- data.frame(x = 1:3, y = letters[1:3])
df2 <- data.frame(x = 4:5, y = letters[4:5])
bind_files(list(a = df1, b = df2))
#>   source x y
#> 1      a 1 a
#> 2      a 2 b
#> 3      a 3 c
#> 4      b 4 d
#> 5      b 5 e

# Force type guessing when types differ:
df3 <- data.frame(x = c("1", "2"))
df4 <- data.frame(x = c(3L, 4L))
bind_files(list(df3, df4), .guess = TRUE)
#> 
#> ── Column specification ────────────────────────────────────────────────────────
#> cols(
#>   x = col_double()
#> )
#>   source x
#> 1      1 1
#> 2      1 2
#> 3      2 3
#> 4      2 4
```
