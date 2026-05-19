# Formatted timestamp for now

A shorthand for `format(lubridate::now(), fmt)`. Useful for constructing
file names and log paths with a timestamp baked in.

## Usage

``` r
nowf(fmt = "%Y%m%d")
```

## Arguments

- fmt:

  Format string as accepted by
  [`strftime()`](https://rdrr.io/r/base/strptime.html). Default is
  `"%Y%m%d"` (ISO date without separators).

## Value

A single character string with the formatted timestamp.

## See also

[`f()`](https://dataniel.github.io/daos/reference/f.md) for string
interpolation

## Examples

``` r
nowf()                 # e.g. "20260518"
#> [1] "20260519"
nowf("%Y%m%d_%H%M%S")  # e.g. "20260518_143022"
#> [1] "20260519_140923"
nowf("%Y%B")           # e.g. "2026May"
#> [1] "2026May"

# Typical use in file paths:
if (FALSE) { # \dontrun{
f("log/{nowf()}/0-check_data.log")
f("data/export_{nowf('%Y%m%d_%H%M%S')}.parquet")
} # }
```
