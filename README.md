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

Three bodies of work grew large enough to leave and become packages of their
own. They are standalone — none of them depends on `daos`, or `daos` on them.

| Package | What it does |
|---------|--------------|
| [taskr](https://github.com/dataniel/taskr) | Taskwarrior-style task management backed by a shared SQLite file |
| [statbank](https://github.com/dataniel/statbank) | Client and keyboard browser for the Greenland and Faroese statbanks |
| [statregn](https://github.com/dataniel/statregn) | Danish annual reports: CVR distribution service, XBRL, and the PDF-to-Excel route |

## Installation

```r
pak::pak("dataniel/daos")
```

## Functions

| Function | Description |
|----------|-------------|
| `%??%` | Null-coalescing operator that returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| `addin_fix_path()` | RStudio addin: replace backslashes with forward slashes in Windows paths |
| `addin_paste_path()` | RStudio addin: paste Windows path from clipboard as a quoted R string |
| `addin_flip_backslash()` | RStudio addin: replace all backslashes with forward slashes in selection |
| `addin_open_in_explorer()` | RStudio addin: open the selected path (or `getwd()`) in the file explorer |
| `addin_text_to_vector()` | RStudio addin: convert selected lines to an R character vector |
| `add_cpr_info()` | Add birth date, age, sex, and validity derived from Danish CPR numbers |
| `browse_files()` | Yazi-style Shiny file browser: mark files/folders and copy paths to R |
| `clean_cpr()` | Standardise CPR numbers: strip separators, restore Excel-lost leading zeros |
| `clean_cvr()` | Standardise CVR numbers: strip separators and the DK VAT prefix |
| `dbdot()` | Format DB07 industry codes with dots (`011100` → `01.11.00`) |
| `drop_all_na()` | Drop rows and/or columns that are entirely `NA` |
| `expect_empty()` | Pipeline checkpoint that warns or aborts if a data frame is non-empty |
| `f()` | String interpolation shorthand (`glue::glue` alias) |
| `find_signs()` | Find sign assignments that reconcile a set of values to a total |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `is_blank()` | Test whether a value is blank in the broadest sense |
| `nowf()` | Formatted current timestamp, e.g. for file names |
| `read_access()` | Read data from a Microsoft Access database via ODBC |
| `read_files()` | Validate paths, read files (auto or custom reader), and optionally bind or unpack |
| `read_ta()` | Read Greenlandic TA files |
| `write_ta()` | Write Greenlandic TA files |
| `screen_timeseries()` | Interactive Shiny dashboard for screening time-series data group by group |
| `shh()` | Suppress messages and warnings during evaluation |
| `split_by()` | Split a data frame into a named list by grouping columns |
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `view_types()` | Compare column types across multiple data frames |
| `write_excel()` | Write data frames to a presentable xlsx: bold frozen header, thousand separators, blank NAs |
| `append_excel()` | Append formatted sheets to an existing xlsx file |
