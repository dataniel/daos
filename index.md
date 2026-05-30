[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/daos)

> **Experimental.** This package is a personal collection of utility
> functions that have grown out of day-to-day statistical work — things
> I kept wishing R had out of the box, patterns I found myself
> repeating, and new ideas I wanted to try out. Rather than letting them
> accumulate as loose scripts, I packaged them up properly with the help
> of Claude Code to get a solid starting point: documentation, tests,
> and a vignette from the start. Consider it a living experiment.

## Installation

``` r
pak::pak("dataniel/daos")
```

## Functions

| Function                                                                                      | Description                                                                                           |
|-----------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `%??%`                                                                                        | Null-coalescing operator — returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""`         |
| `%like%`                                                                                      | Regex matching that preserves `NA` (unlike `grepl`)                                                   |
| [`accounts_pdf_to_txt()`](https://dataniel.github.io/daos/reference/accounts_pdf_to_txt.md)   | Convert PDF financial statements to text files                                                        |
| [`addin_fix_path()`](https://dataniel.github.io/daos/reference/addin_fix_path.md)             | RStudio addin: replace backslashes with forward slashes in Windows paths                              |
| [`addin_flip_backslash()`](https://dataniel.github.io/daos/reference/addin_flip_backslash.md) | RStudio addin: replace all backslashes with forward slashes in selection                              |
| [`addin_text_to_vector()`](https://dataniel.github.io/daos/reference/addin_text_to_vector.md) | RStudio addin: convert selected lines to an R character vector                                        |
| [`accounts_txt_to_xlsx()`](https://dataniel.github.io/daos/reference/accounts_txt_to_xlsx.md) | Parse manually formatted text files and export to Excel                                               |
| [`cpr_info()`](https://dataniel.github.io/daos/reference/cpr_info.md)                         | Extract birth date, age, sex, and validity from Danish CPR numbers                                    |
| [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)                 | Pipeline checkpoint — warn or abort if a data frame is non-empty                                      |
| [`f()`](https://dataniel.github.io/daos/reference/f.md)                                       | String interpolation shorthand ([`glue::glue`](https://glue.tidyverse.org/reference/glue.html) alias) |
| [`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md)                     | Find sign assignments that reconcile a set of values to a total                                       |
| [`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)           | Prepend `isdup`/`dupid` columns to mark duplicate rows                                                |
| [`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)                         | Test whether a value is blank in the broadest sense                                                   |
| [`nowf()`](https://dataniel.github.io/daos/reference/nowf.md)                                 | Formatted current timestamp, e.g. for file names                                                      |
| [`quiet()`](https://dataniel.github.io/daos/reference/quiet.md)                               | Suppress messages and warnings during evaluation                                                      |
| [`read_access()`](https://dataniel.github.io/daos/reference/read_access.md)                   | Read data from a Microsoft Access database via ODBC                                                   |
| [`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)                     | Validate paths, read files (auto or custom reader), and optionally bind or unpack                     |
| [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)                           | Read Greenlandic TA files                                                                             |
| [`read_xbrl()`](https://dataniel.github.io/daos/reference/read_xbrl.md)                       | Parse an XBRL file into a tidy tibble                                                                 |
| [`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)       | Interactive Shiny dashboard for screening time-series data group by group                             |
| [`size_env()`](https://dataniel.github.io/daos/reference/size_env.md)                         | Show object sizes in an environment                                                                   |
| [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)                         | Split a data frame into a named list by grouping columns                                              |
| [`summon()`](https://dataniel.github.io/daos/reference/summon.md)                             | Retrieve objects matching a regex pattern from an environment                                         |
| [`track_last_df()`](https://dataniel.github.io/daos/reference/track_last_df.md)               | Auto-save the last printed data frame as `.last.df`                                                   |
| [`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)                     | Compare column types across multiple data frames                                                      |
| [`write_pretty_xlsx()`](https://dataniel.github.io/daos/reference/write_pretty_xlsx.md)       | Write data frames to xlsx with sensible defaults: bold frozen header, thousand separators, blank NAs  |
