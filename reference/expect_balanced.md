# Assert that a panel is balanced, or has no gaps

A checkpoint for register panels: every unit (person, company,
workplace) must be observed in every period. Missing unit-periods are
the violation set, so a failure lists exactly which units lack which
periods. Returns `data`, so it can sit in the middle of a pipeline.

## Usage

``` r
expect_balanced(
  data,
  id,
  time,
  periods = NULL,
  gaps_only = FALSE,
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

- id:

  Column(s) identifying the unit (tidy-select), e.g. `cpr` or
  `c(cvr, lbnr)`.

- time:

  The period column (one column), e.g. `year`. Any type that sorts, such
  as integer years or dates.

- periods:

  Expected periods. Defaults to the periods observed in `data`.

- gaps_only:

  If `FALSE` (default), every unit must be observed in every period. If
  `TRUE`, only periods between a unit's first and last observation are
  required.

- success_msg:

  Message shown (and logged) when `data` is empty. If `NULL` (default),
  it is `"Check passed: <message>"` when `warn_msg` or `abort_msg` is
  given, so the log names every check that ran, and
  `"The dataset is empty."` otherwise.

- warn_msg:

  Message shown (and logged) when unit-periods are missing and no
  `abort_msg` is set. Defaults to a description of the check.

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

Register populations are rarely fully balanced: people are born, die and
migrate, and firms open and close. `gaps_only = TRUE` relaxes the rule
to what usually *should* hold: a unit may enter late and leave early,
but once present it must not skip a period between its first and last. A
person present in 2019 and 2021 but missing in 2020 is then a gap; a
person first seen in 2021 is not.

### What counts as a period

By default the expected periods are those observed anywhere in the data.
A period missing for *every* unit (e.g. a year that was never loaded) is
therefore invisible. Pass the periods you expect, e.g.
`periods = 2015:2024`, to catch that too. Observations outside `periods`
are ignored, as are rows with a missing period.

Duplicated unit-periods do not make a panel unbalanced, but they are
usually an error of their own: check them with
[`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md)`(data, id, time)`.

The check scales to full-population registers: the unit-period grid is
only built for units that actually lack a period.

## See also

[`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md)
for duplicated unit-periods,
[`expect_no_overlap()`](https://dataniel.github.io/daos/reference/expect_no_overlap.md)
for spell data,
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md).

## Examples

``` r
panel <- data.frame(
  cpr  = c("a", "a", "a", "b", "b", "c"),
  year = c(2020, 2021, 2022, 2020, 2022, 2022)
)

# Not balanced: b lacks 2021, c lacks 2020 and 2021
expect_balanced(panel, cpr, year)
#> Warning: Panel is not balanced: missing cpr-year combinations
#> ℹ 3 rows found:
#>   cpr = "b", year = 2021
#>   cpr = "c", year = 2020
#>   cpr = "c", year = 2021

# Only gaps: b lacks 2021; c simply entered in 2022
expect_balanced(panel, cpr, year, gaps_only = TRUE)
#> Warning: Gaps in panel: missing cpr-year combinations
#> ℹ 1 row found:
#>   cpr = "b", year = 2021

# A year missing for everyone is only found with explicit periods
expect_balanced(panel, cpr, year, periods = 2019:2022, gaps_only = TRUE)
#> Warning: Gaps in panel: missing cpr-year combinations
#> ℹ 1 row found:
#>   cpr = "b", year = 2021
```
