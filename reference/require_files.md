# Validate and resolve file paths

Expands paths using
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html) (so
`{0:9}` generates ten paths), checks that every file exists, and returns
a named character vector ready to pipe into
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md).
Aborts immediately if any file is missing.

## Usage

``` r
require_files(paths, .names = NULL, .envir = parent.frame())
```

## Arguments

- paths:

  A character vector of file paths. Glue syntax
  ([`{}`](https://rdrr.io/r/base/Paren.html)) is supported for compact
  range expansion.

- .names:

  Optional character vector of names to assign to the returned paths.
  Defaults to the file name without extension.

- .envir:

  Environment used for glue interpolation. Default is the calling frame.

## Value

A named character vector of validated file paths.

## See also

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md),
[`bind_files()`](https://dataniel.github.io/daos/reference/bind_files.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate ten files at once using glue expansion:
require_files("data/dat{0:9}.parquet")

# Pipe directly into read_files():
require_files("data/dat{0:9}.parquet") |> read_files()

# Full pipeline: validate -> read -> bind:
require_files("data/dat{0:9}.parquet") |>
  read_files() |>
  bind_files()
} # }
```
