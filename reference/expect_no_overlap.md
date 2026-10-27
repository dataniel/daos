# Assert that spells do not overlap within a unit

A checkpoint for spell data, the other common shape of register data:
address periods, employment spells, benefit periods. Each unit can only
be in one spell at a time, so two spells for the same person that share
a day are an error. Returns `data`, so it can sit in the middle of a
pipeline.

## Usage

``` r
expect_no_overlap(
  data,
  id,
  start,
  end,
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

  Column(s) identifying the unit (tidy-select), e.g. `cpr`.

- start, end:

  Columns with the first and last period of each spell (dates, or
  integers such as years).

- success_msg:

  Message shown (and logged) when `data` is empty. If `NULL` (default),
  it is `"Check passed: <message>"` when `warn_msg` or `abort_msg` is
  given, so the log names every check that ran, and
  `"The dataset is empty."` otherwise.

- warn_msg:

  Message shown (and logged) when spells overlap and no `abort_msg` is
  set. Defaults to a description of the check.

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

On failure the overlapping spells are reported with an `overlap_id`
column prepended, in the spirit of `dupid` in
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md):
spells that overlap each other (directly or through a chain) share an
id, so each conflict can be inspected as a group.

Spells are treated as closed intervals, as register dates usually are: a
spell ending 31 January and one starting 1 February do not overlap,
while one ending and one starting on 1 February do. A missing `end`
means an ongoing spell and overlaps everything after its start. Rows
with a missing `start` are ignored; check them with
[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)`(data, is.na(start))`,
and spells that end before they start with
[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)`(data, end < start)`.

## See also

[`expect_balanced()`](https://dataniel.github.io/daos/reference/expect_balanced.md)
for yearly panels,
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md).

## Examples

``` r
addresses <- data.frame(
  cpr   = c("a", "a", "b", "b"),
  start = as.Date(c("2020-01-01", "2021-01-01", "2020-01-01", "2020-06-01")),
  end   = as.Date(c("2020-12-31", NA,           "2020-06-30", "2021-12-31"))
)

# b has two addresses in June 2020
expect_no_overlap(addresses, cpr, start, end)
#> Warning: Overlapping spells per cpr
#> ℹ 2 rows found:
#>   overlap_id = 1, cpr = "b", start = 2020-01-01, end = 2020-06-30
#>   overlap_id = 1, cpr = "b", start = 2020-06-01, end = 2021-12-31
```
