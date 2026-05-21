# Extended null-coalescing operator

Returns `default` when `x` is `NULL`, has length 0, consists entirely of
`NA` values, or (for character vectors) consists entirely of empty
strings. Otherwise returns `x` unchanged.

## Usage

``` r
x %??% default
```

## Arguments

- x:

  Value to test.

- default:

  Fallback value returned when `x` is blank.

## Value

`x` if non-blank, otherwise `default`.

## Details

More intuitive than
[`rlang::%||%`](https://rdrr.io/pkg/rlang/man/op-null-default.html) in
data-cleaning contexts where empty strings and all-`NA` vectors should
be treated as missing.

## See also

[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)

## Examples

``` r
NULL %??% "default"
#> [1] "default"
NA %??% 0
#> [1] 0
"" %??% "unknown"
#> [1] "unknown"
c(NA, NA) %??% "missing"
#> [1] "missing"
42 %??% 99
#> [1] 42
```
