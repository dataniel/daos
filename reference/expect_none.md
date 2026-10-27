# Assert that no rows match a condition

The in-pipeline form of
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md).
Instead of filtering for the violations and piping *them* in, pass the
condition directly. The check is the same, but `data` itself is
returned, so the pipeline continues with all rows:

## Usage

``` r
expect_none(
  data,
  ...,
  success_msg = NULL,
  warn_msg = NULL,
  abort_msg = NULL,
  log = getOption("daos.check_log"),
  dump = getOption("daos.check_dump")
)
```

## Arguments

- data:

  A data frame or tibble.

- ...:

  Conditions that describe a violating row, as in
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).

- success_msg:

  Message shown (and logged) when `data` is empty. If `NULL` (default),
  it is `"Check passed: <message>"` when `warn_msg` or `abort_msg` is
  given, so the log names every check that ran, and
  `"The dataset is empty."` otherwise.

- warn_msg:

  Message shown (and logged) when rows match and no `abort_msg` is set.
  Defaults to a description of the condition.

- abort_msg:

  If provided,
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  is called with this message when `data` is not empty. If `NULL`
  (default), a warning is issued instead.

- log:

  Optional path to a log file. The directory is created automatically.
  Defaults to `getOption("daos.check_log")`.

- dump:

  Optional directory. When the check fails, the offending rows are
  written there as a timestamped CSV file (UTF-8 with BOM, so Excel
  reads æøå correctly). Defaults to `getOption("daos.check_dump")`.

## Value

`data` invisibly, unchanged.

## Details

    df |>
      expect_none(is.na(id), abort_msg = "Rows without an id") |>
      expect_none(amount < 0) |>
      mutate(...)

Conditions follow
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
semantics: several conditions are combined with `&`, and a row where a
condition is `NA` does not count as a violation. Test for missing values
explicitly with [`is.na()`](https://rdrr.io/r/base/NA.html) when they
matter.

Without a message, the condition itself becomes the message
(`"Found rows where amount < 0"`), which is often clear enough during
exploration. Write your own message for checks that stay in production.

## See also

[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md),
[`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md),
[`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md)

## Examples

``` r
ggplot2::mpg |>
  expect_none(cyl < 4) |>
  expect_none(hwy > 40, warn_msg = "Implausibly efficient cars") |>
  nrow()
#> ✔ No rows where cyl < 4
#> Warning: Implausibly efficient cars
#> ℹ 3 rows found:
#>   manufacturer = "volkswagen", model = "jetta", displ = 1.9, year = 1999, cyl =
#>   4, trans = "manual(...
#>   manufacturer = "volkswagen", model = "new beetle", displ = 1.9, year = 1999,
#>   cyl = 4, trans = "ma...
#>   manufacturer = "volkswagen", model = "new beetle", displ = 1.9, year = 1999,
#>   cyl = 4, trans = "au...
#> [1] 234

if (FALSE) { # \dontrun{
dplyr::starwars |>
  expect_none(is.na(species), abort_msg = "Characters without a species")
} # }
```
