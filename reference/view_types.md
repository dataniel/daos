# Compare column types across data frames

Shows the column types of one or more data frames side-by-side, and
classifies each column by whether the datasets could be row-bound as
they are. Useful for diagnosing type mismatches before a join or before
binding with `lazer::read_files()`.

## Usage

``` r
view_types(..., diff = FALSE, focus = NULL)
```

## Arguments

- ...:

  Data frames to compare (unquoted), or a single named list of data
  frames, such as the default output of `lazer::read_files()`. A list
  can also be spliced with `!!!`. Names are inferred from the
  expressions passed, or taken from the list.

- diff:

  Logical. If `TRUE`, only columns with status `"conflict"` are shown,
  so frames that bind produce an empty result. To see every difference,
  filter on `status != "ok"` instead. Default: `FALSE`.

- focus:

  A named character vector of expected types, e.g.
  `c(cvr = "chr", year = "int")`. When supplied, only the named columns
  are shown, and only for datasets where the type does **not** match (an
  absent column counts as a mismatch). Returns an empty tibble (0 rows)
  when all types match, so it can be used in checkpoints. Takes
  precedence over `diff`.

## Value

A tibble with a `column` column, a `status` column (see Details) and one
column per input dataset showing an abbreviated type string (`"int"`,
`"dbl"`, `"chr"`, `"fct"`, `"date"`, `"dttm"`, ...). `NA` means the
column is absent from that dataset.

## Details

A type string alone does not say whether two data frames can be stacked:
`int` and `dbl` bind without trouble, and so does a column that is
entirely `NA` (readr reads an empty column as `lgl`). A column that is
absent from one dataset is no obstacle either, since
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
fills it with `NA`. Only a real conflict such as `chr` vs `dbl` makes
the bind fail, or forces `lazer::read_files()` to fall back to
character. The `status` column therefore asks the question the function
is called for: does it bind?

- `"ok"`: present everywhere with the same type.

- `"coercible"`: present everywhere, types differ but bind without loss
  of structure (`int` + `dbl`, `fct` + `chr`, `date` + `dttm`, an
  all-`NA` `lgl` with anything).

- `"missing"`: absent from at least one dataset, no conflict among the
  rest. Typically a rename or a dropped column upstream.

- `"conflict"`: the types cannot be combined.

Compatibility is tested by binding zero-row slices of each column with
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html),
so the classification follows the same rules as
`read_files(out = "bind")`.

## See also

`lazer::read_files()`, and
[`expectr::expect_empty()`](https://dataniel.github.io/expectr/reference/expect_empty.html)
to use `view_types(diff = TRUE)` or `focus` as a checkpoint

## Examples

``` r
df1 <- data.frame(x = 1L,  y = "a", z = NA)
df2 <- data.frame(x = 1.0, y = 2,   z = "b")

view_types(df1, df2)
#> # A tibble: 3 × 4
#>   column status    df1   df2  
#>   <chr>  <chr>     <chr> <chr>
#> 1 x      coercible int   dbl  
#> 2 y      conflict  chr   dbl  
#> 3 z      coercible lgl   chr  
view_types(df1, df2, diff = TRUE)
#> # A tibble: 1 × 4
#>   column status   df1   df2  
#>   <chr>  <chr>    <chr> <chr>
#> 1 y      conflict chr   dbl  
view_types(df1, df2, focus = c(x = "int", y = "chr"))
#> # A tibble: 2 × 3
#>   column status    df2  
#>   <chr>  <chr>     <chr>
#> 1 x      coercible dbl  
#> 2 y      conflict  dbl  

# A named list of data frames, e.g. from read_files():
view_types(list(a = df1, b = df2))
#> # A tibble: 3 × 4
#>   column status    a     b    
#>   <chr>  <chr>     <chr> <chr>
#> 1 x      coercible int   dbl  
#> 2 y      conflict  chr   dbl  
#> 3 z      coercible lgl   chr  
```
