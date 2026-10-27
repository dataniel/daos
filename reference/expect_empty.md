# Assert that a data frame is empty

A pipeline-friendly validation checkpoint. Express a rule as "the set of
violations must be empty", build that set with an ordinary
[`filter()`](https://rdrr.io/r/stats/filter.html), and pipe it in. Emits
a success alert when the data frame has zero rows, otherwise warns or
aborts with the number of offending rows and a preview of the first few.

## Usage

``` r
expect_empty(
  data,
  success_msg = NULL,
  warn_msg = "The dataset is not empty.",
  abort_msg = NULL,
  log = getOption("daos.check_log"),
  dump = getOption("daos.check_dump")
)
```

## Arguments

- data:

  A data frame or tibble.

- success_msg:

  Message shown (and logged) when `data` is empty. If `NULL` (default),
  it is `"Check passed: <message>"` when `warn_msg` or `abort_msg` is
  given, so the log names every check that ran, and
  `"The dataset is empty."` otherwise.

- warn_msg:

  Message shown (and logged) when `data` is not empty and no `abort_msg`
  is set. Default: `"The dataset is not empty."`.

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

`data` invisibly.

## Details

Messages are shown literally: braces are not interpolated, so regular
expressions such as `"^\\d{8}$"` are safe to use in a message.

A failed check signals a condition of class `daos_check_failure` (a
warning or an error) that carries the offending rows in its `violations`
field. Scheduled pipelines can catch it and keep the rows:

    tryCatch(
      expect_empty(bad_rows, abort_msg = "Bad rows"),
      daos_check_failure = \(e) saveRDS(e$violations, "bad_rows.rds")
    )

### Logging and dumping

`log` appends one line per check to a text file, and `dump` writes the
offending rows to a CSV file in a directory. Both default to a global
option, so a script can switch them on once at the top instead of
repeating the path in every check:

    options(
      daos.check_log  = f("log/{nowf()}_checks.log"),
      daos.check_dump = "log/violations"
    )

A log line has the form `time | symbol | message | rows [| dump file]`:

    2026-06-11 09:00:03 | ✔ | Check passed: NA ids | 0 rows
    2026-06-11 09:00:03 | ! | Negative amounts | 3 rows | log/violations/20260611_090003_Negative_amounts.csv

## See also

[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)
to check a condition without leaving the pipeline,
[`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md)
for keys,
[`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md)
to run many rules at once, and
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md).

## Examples

``` r
# Success: no rows
data.frame() |> expect_empty()
#> ✔ The dataset is empty.

# Warning: unexpected rows
dplyr::filter(ggplot2::mpg, cyl > 6) |>
  expect_empty(warn_msg = "Eight-cylinder cars found")
#> Warning: Eight-cylinder cars found
#> ℹ 70 rows found:
#>   manufacturer = "audi", model = "a6 quattro", displ = 4.2, year = 2008, cyl =
#>   8, trans = "auto(s6)...
#>   manufacturer = "chevrolet", model = "c1500 suburban 2wd", displ = 5.3, year =
#>   2008, cyl = 8, tran...
#>   manufacturer = "chevrolet", model = "c1500 suburban 2wd", displ = 5.3, year =
#>   2008, cyl = 8, tran...
#>   manufacturer = "chevrolet", model = "c1500 suburban 2wd", displ = 5.3, year =
#>   2008, cyl = 8, tran...
#>   manufacturer = "chevrolet", model = "c1500 suburban 2wd", displ = 5.7, year =
#>   1999, cyl = 8, tran...
#>   ... and 65 more

# Abort: treat unexpected rows as a hard error
if (FALSE) { # \dontrun{
dplyr::filter(dplyr::starwars, height < 0) |>
  expect_empty(abort_msg = "Impossible: negative height")
} # }

# With logging, set once for the whole script:
if (FALSE) { # \dontrun{
options(daos.check_log = f("log/{nowf()}/checks.log"))

dplyr::starwars |>
  dplyr::filter(name == "Harry Potter") |>
  expect_empty(warn_msg = "Harry Potter rows")
} # }
```
