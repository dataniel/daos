# Show object sizes in an environment

Lists all objects in an environment sorted by size (descending), with
both raw byte counts and human-readable representations.

## Usage

``` r
size_env(.envir = parent.frame(), n = NULL)
```

## Arguments

- .envir:

  The environment to inspect. Default is the calling environment.

- n:

  Optional integer. If supplied, only the `n` largest objects are
  returned.

## Value

A tibble with columns `name` (character), `size` (numeric, bytes), and
`pretty` (character, human-readable). Returns `NULL` invisibly if the
environment is empty.

## Examples

``` r
x <- 1:1e6
y <- letters
size_env()       # all objects
#> # A tibble: 2 × 3
#>   name     size pretty
#>   <chr>   <dbl> <chr> 
#> 1 x     4000048 3.8 Mb
#> 2 y        1712 1.7 Kb
size_env(n = 1)  # only the largest
#> # A tibble: 1 × 3
#>   name     size pretty
#>   <chr>   <dbl> <chr> 
#> 1 x     4000048 3.8 Mb
```
