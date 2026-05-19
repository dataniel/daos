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

### General utilities

| Function                                                              | Description                                                                                           |
|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `%??%`                                                                | Null-coalescing operator — returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""`         |
| `%like%`                                                              | Regex matching that preserves `NA` (unlike `grepl`)                                                   |
| [`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md) | Test whether a value is blank in the broadest sense                                                   |
| [`f()`](https://dataniel.github.io/daos/reference/f.md)               | String interpolation shorthand ([`glue::glue`](https://glue.tidyverse.org/reference/glue.html) alias) |
| [`nowf()`](https://dataniel.github.io/daos/reference/nowf.md)         | Formatted current timestamp, e.g. for file names                                                      |
| [`quiet()`](https://dataniel.github.io/daos/reference/quiet.md)       | Suppress messages and warnings during evaluation                                                      |

### File workflow

| Function                                                                        | Description                                                      |
|---------------------------------------------------------------------------------|------------------------------------------------------------------|
| [`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)       | Auto-detect format and read one or more files                    |
| [`require_files()`](https://dataniel.github.io/daos/reference/require_files.md) | Validate paths (with glue expansion) before reading              |
| [`bind_files()`](https://dataniel.github.io/daos/reference/bind_files.md)       | Row-bind a list of data frames with helpful type-mismatch errors |
| [`unpack_files()`](https://dataniel.github.io/daos/reference/unpack_files.md)   | Assign list elements as individual variables                     |

### Data wrangling

| Function                                                                            | Description                                                    |
|-------------------------------------------------------------------------------------|----------------------------------------------------------------|
| [`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)           | Compare column types across multiple data frames               |
| [`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md) | Prepend `isdup`/`dupid` columns to mark duplicate rows         |
| [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)       | Pipeline checkpoint — warn or abort if data frame is non-empty |
| [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)               | Split a data frame into a named list by grouping columns       |

### Environment

| Function                                                                        | Description                                                   |
|---------------------------------------------------------------------------------|---------------------------------------------------------------|
| [`summon()`](https://dataniel.github.io/daos/reference/summon.md)               | Retrieve objects matching a regex pattern from an environment |
| [`size_env()`](https://dataniel.github.io/daos/reference/size_env.md)           | Show object sizes in an environment                           |
| [`track_last_df()`](https://dataniel.github.io/daos/reference/track_last_df.md) | Auto-save the last printed data frame as `.last.df`           |

### Domain-specific

| Function                                                                  | Description                                                        |
|---------------------------------------------------------------------------|--------------------------------------------------------------------|
| [`cpr_info()`](https://dataniel.github.io/daos/reference/cpr_info.md)     | Extract birth date, age, sex, and validity from Danish CPR numbers |
| [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)       | Read Greenlandic TA files                                          |
| [`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md) | Find sign assignments that reconcile a set of values to a total    |

### Interactive

| Function                                                                    | Description                                                |
|-----------------------------------------------------------------------------|------------------------------------------------------------|
| [`time2screen()`](https://dataniel.github.io/daos/reference/time2screen.md) | Interactive Shiny dashboard for screening time-series data |
