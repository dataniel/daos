# Retrieve objects matching a pattern from an environment

Searches an environment for objects whose names match a regular
expression and returns them as a named list. Useful for collecting a
family of similarly-named objects (e.g. `dat0` through `dat9`) after
unpacking a list with `unpack_files()`.

## Usage

``` r
summon(pattern, .envir = parent.frame())
```

## Arguments

- pattern:

  A single regular expression string.

- .envir:

  The environment to search. Default is the calling environment.

## Value

A named list of matching objects.

## See also

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md),
[`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)

## Examples

``` r
dat1 <- data.frame(x = 1)
dat2 <- data.frame(x = 2)
dat3 <- data.frame(x = 3)
summon("^dat\\d+$")
#> $dat1
#>   x
#> 1 1
#> 
#> $dat2
#>   x
#> 1 2
#> 
#> $dat3
#>   x
#> 1 3
#> 
```
