# daos

[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/daos)

> **Experimental.** This package is a personal collection of utility functions
> that have grown out of day-to-day statistical work: things I kept wishing R
> had out of the box, patterns I found myself repeating, and new ideas I wanted
> to try out. Rather than letting them accumulate as loose scripts, I packaged
> them up properly with the help of Claude Code to
> get a solid starting point: documentation, tests, and a vignette from the
> start. Consider it a living experiment.

## Related packages

Five bodies of work grew large enough to leave and become packages of their
own. They are standalone — none of them depends on `daos`, or `daos` on them.

| Package | What it does |
|---------|--------------|
| [taskr](https://github.com/dataniel/taskr) | Taskwarrior-style task management backed by a shared SQLite file |
| [statbank](https://github.com/dataniel/statbank) | Client and keyboard browser for the Greenland and Faroese statbanks |
| [cvrr](https://github.com/dataniel/cvrr) | Published Danish annual reports: the CVR distribution service, XBRL, and sign reconciliation |
| [taxmill](https://github.com/dataniel/taxmill) | PDF financial statements milled into a tidy Excel dataset, locally |
| [pathr](https://github.com/dataniel/pathr) | Frictionless file paths: a file browser, open-in-explorer, and RStudio addins for pasted Windows paths |

## Installation

```r
pak::pak("dataniel/daos")
```

## What it looks like

**Reading a set of files.** `read_files()` replaces the usual
`list.files()` + loop + naming pipeline with one call that expands paths,
checks they exist, detects the format, and names the results.

```r
library(daos)

# One file returns the object; several return a named list
df  <- read_files("data/results.parquet")
lst <- read_files("data/dat{0:9}.parquet", names = 0:9)

# Or row-bind them, keeping track of where each row came from
panel <- read_files(
  "data/dat{2020:2024}.parquet",
  names = 2020:2024,
  out   = "bind",
  .id   = "year"
)
```

If it handles a set of files without warnings, the production upstream is
consistent. When it warns about type mismatches, something changed — and
`view_types()` shows which column, in which file.

**Checkpoints instead of silent assumptions.** Filter for the rows that
should not exist and pipe them into `expect_empty()`. If any turn up, you
get the offending rows and a message in your own words, not a stack trace.

```r
sales |>
  dplyr::filter(is.na(customer_id)) |>
  expect_empty(abort_msg = "Sales rows without a customer id")

sales |>
  dplyr::filter(amount < 0) |>
  expect_empty(warn_msg = "Negative amounts", log = "checks.log")
```

**Danish and Greenlandic identifiers, and a file a colleague can read.**

```r
customers |>
  dplyr::mutate(cpr = clean_cpr(cpr)) |>   # restores Excel-lost leading zeros
  add_cpr_info(cpr) |>                     # birth date, age, sex, validity
  write_excel(f("customers_{nowf()}.xlsx"))
```

`write_excel()` writes an xlsx meant to be opened by a person: bold frozen
header, thousand separators, blank cells for `NA`. `f()` is `glue::glue()`
under a shorter name, and `nowf()` is a formatted timestamp.

## Functions

| Function | Description |
|----------|-------------|
| `%??%` | Null-coalescing operator that returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| `add_cpr_info()` | Add birth date, age, sex, and validity derived from Danish CPR numbers |
| `age()` | Choose the reference year or date for an age column in `add_cpr_info()` |
| `clean_cpr()` | Standardise CPR numbers: strip separators, restore Excel-lost leading zeros |
| `clean_cvr()` | Standardise CVR numbers: strip separators and the DK VAT prefix |
| `format_db07()` | Automatically handle mixed DB07 input; choose dotted (`01.11.00`) or compact (`011100`) output |
| `db_label()` | Look up Danish industry labels with an explicit DB07 or DB25 version |
| `inspect_db()` | Inspect mixed full DB07/DB25 codes; flag shared codes and show both labels |
| `convert_db07_to_db25()` / `convert_db25_to_db07()` | Convert full industry codes using DST's bundled keys; strict or simplified mapping |
| `drop_empty_rows()` | Drop rows empty across selected columns; optionally include blank text |
| `drop_empty_cols()` | Drop entirely empty selected columns |
| `expect_balanced()` | Checkpoint: every unit observed in every period, or no gaps (`gaps_only`) |
| `expect_empty()` | Pipeline checkpoint that warns or aborts if a data frame is non-empty |
| `expect_no_overlap()` | Checkpoint: spells (addresses, employment) do not overlap within a unit |
| `expect_none()` | Checkpoint: no row matches a condition; returns the full data for chaining |
| `expect_unique()` | Checkpoint: key columns identify each row uniquely |
| `f()` | String interpolation shorthand (`glue::glue` alias) |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `is_blank()` | Test whether a value is blank in the broadest sense |
| `nowf()` | Formatted current timestamp, e.g. for file names |
| `read_access()` | Read data from a Microsoft Access database via ODBC |
| `read_files()` | Validate paths, read files (auto or custom reader), and optionally bind or unpack |
| `read_ta()` | Read Greenlandic TA files (old layout) |
| `write_ta()` | Write Greenlandic TA files (old layout) |
| `read_ta2()` | Read Greenlandic TA files (new 140-character layout) |
| `write_ta2()` | Write Greenlandic TA files (new 140-character layout) |
| `screen_timeseries()` | Fast interactive time-series screening with optional in-app diagnostics and seasonal plots |
| `diagnose_timeseries()` | Time-series statistics, seasonal/outlier screening, stationarity and structural breaks, optionally by group |
| `shh()` | Suppress messages and warnings during evaluation |
| `split_by()` | Split a data frame into a named list by grouping columns |
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `tally_violations()` | Count violations for many rules at once (counts, never judges); filter and pipe into `expect_empty()` |
| `view_types()` | Compare column types across multiple data frames |
| `write_excel()` | Format xlsx with configurable `digits`; choose `new`, `append`, `replace` (sheets), or `overwrite` (whole file) |
