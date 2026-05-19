# Unpack a named list into individual variables

Assigns each element of a named list to its own variable in a target
environment. This is the complement of
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
when you want individual named objects rather than a single list.

## Usage

``` r
unpack_files(data, .envir = parent.frame(), .overwrite = FALSE)
```

## Arguments

- data:

  A fully named list.

- .envir:

  Target environment. Default is the calling environment.

- .overwrite:

  If `FALSE` (default), aborts when any name already exists in the
  target environment. Set to `TRUE` to allow overwrites.

## Value

`data` invisibly.

## See also

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md),
[`summon()`](https://dataniel.github.io/daos/reference/summon.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Read files into separate variables:
require_files("data/dat{0:9}.parquet") |>
  read_files() |>
  unpack_files()

# dat0, dat1, ..., dat9 now exist in the environment.
# Collect them again:
summon("^dat\\d+$")
} # }
```
