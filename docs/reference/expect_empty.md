# Assert that a data frame is empty

A pipeline-friendly validation checkpoint. Emits a success alert when
the data frame has zero rows, otherwise warns or aborts. Optionally
appends a timestamped entry to a log file — useful for automated
pipelines where you want a minimal audit trail without noise.

## Usage

``` r
expect_empty(
  data,
  success_msg = "The dataset is empty.",
  warn_msg = "The dataset is not empty.",
  abort_msg = NULL,
  log = NULL
)
```

## Arguments

- data:

  A data frame or tibble.

- success_msg:

  Message shown (and logged) when `data` is empty. Default:
  `"The dataset is empty."`.

- warn_msg:

  Message shown (and logged) when `data` is not empty and no `abort_msg`
  is set. Default: `"The dataset is not empty."`.

- abort_msg:

  If provided,
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  is called with this message when `data` is not empty. If `NULL`
  (default), a warning is issued instead.

- log:

  Optional path to a log file. The directory is created automatically if
  it does not exist. Each entry is prefixed with a timestamp and a
  symbol (`✔`, `✖`, or `!`).

## Value

`data` invisibly.

## See also

[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)

## Examples

``` r
# Success — no rows
data.frame() |> expect_empty()
#> ✔ The dataset is empty.

# Warning — unexpected rows
dplyr::filter(ggplot2::mpg, cyl < 0) |>
  expect_empty(warn_msg = "Negative cylinder counts found")
#> ✔ The dataset is empty.

# Abort — treat unexpected rows as a hard error
if (FALSE) { # \dontrun{
dplyr::filter(dplyr::starwars, height < 0) |>
  expect_empty(abort_msg = "Impossible: negative height")
} # }

# With logging:
if (FALSE) { # \dontrun{
log_path <- f("log/{nowf()}/checks.log")
checker  <- purrr::partial(expect_empty, log = log_path)

dplyr::filter(dplyr::starwars, name == "Harry Potter") |>
  checker(success_msg = "No Harry Potter rows")
} # }
```
