# daos

[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/daos)

> **Experimental.** This package is a personal collection of utility functions
> that have grown out of day-to-day statistical work — things I kept wishing R
> had out of the box, patterns I found myself repeating, and new ideas I wanted
> to try out. Rather than letting them accumulate as loose scripts, I packaged
> them up properly with the help of Claude Code to
> get a solid starting point: documentation, tests, and a vignette from the
> start. Consider it a living experiment.

## Installation

```r
pak::pak("dataniel/daos")
```

## Functions

| Function | Description |
|----------|-------------|
| `%??%` | Null-coalescing operator — returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| `accounts_pdf_to_txt()` | Convert PDF financial statements to text files |
| `addin_fix_path()` | RStudio addin: replace backslashes with forward slashes in Windows paths |
| `addin_paste_path()` | RStudio addin: paste Windows path from clipboard as a quoted R string |
| `addin_flip_backslash()` | RStudio addin: replace all backslashes with forward slashes in selection |
| `addin_open_in_explorer()` | RStudio addin: open the selected path (or `getwd()`) in the file explorer |
| `addin_text_to_vector()` | RStudio addin: convert selected lines to an R character vector |
| `accounts_txt_to_xlsx()` | Parse manually formatted text files and export to Excel |
| `cpr_info()` | Extract birth date, age, sex, and validity from Danish CPR numbers |
| `drop_all_na()` | Drop rows and/or columns that are entirely `NA` |
| `expect_empty()` | Pipeline checkpoint — warn or abort if a data frame is non-empty |
| `f()` | String interpolation shorthand (`glue::glue` alias) |
| `find_signs()` | Find sign assignments that reconcile a set of values to a total |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `is_blank()` | Test whether a value is blank in the broadest sense |
| `nowf()` | Formatted current timestamp, e.g. for file names |
| `quiet()` | Suppress messages and warnings during evaluation |
| `read_access()` | Read data from a Microsoft Access database via ODBC |
| `read_files()` | Validate paths, read files (auto or custom reader), and optionally bind or unpack |
| `read_ta()` | Read Greenlandic TA files |
| `write_ta()` | Write Greenlandic TA files |
| `read_xbrl()` | Parse an XBRL file into a tidy tibble |
| `screen_timeseries()` | Interactive Shiny dashboard for screening time-series data group by group |
| `size_env()` | Show object sizes in an environment |
| `split_by()` | Split a data frame into a named list by grouping columns |
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `track_last_df()` | Auto-save the last printed data frame as `.last.df` |
| `view_types()` | Compare column types across multiple data frames |
| `write_pretty_xlsx()` | Write data frames to xlsx with sensible defaults: bold frozen header, thousand separators, blank NAs |
