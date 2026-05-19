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

### General utilities

| Function | Description |
|----------|-------------|
| `%??%` | Null-coalescing operator — returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| `is_blank()` | Test whether a value is blank in the broadest sense |
| `f()` | String interpolation shorthand (`glue::glue` alias) |
| `nowf()` | Formatted current timestamp, e.g. for file names |
| `quiet()` | Suppress messages and warnings during evaluation |

### File workflow

| Function | Description |
|----------|-------------|
| `read_files()` | Validate paths, read files (auto or custom reader), and optionally bind or unpack |

### Data wrangling

| Function | Description |
|----------|-------------|
| `view_types()` | Compare column types across multiple data frames |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `expect_empty()` | Pipeline checkpoint — warn or abort if data frame is non-empty |
| `split_by()` | Split a data frame into a named list by grouping columns |

### Environment

| Function | Description |
|----------|-------------|
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `size_env()` | Show object sizes in an environment |
| `track_last_df()` | Auto-save the last printed data frame as `.last.df` |

### Domain-specific

| Function | Description |
|----------|-------------|
| `cpr_info()` | Extract birth date, age, sex, and validity from Danish CPR numbers |
| `read_ta()` | Read Greenlandic TA files |
| `find_signs()` | Find sign assignments that reconcile a set of values to a total |

### Interactive

| Function | Description |
|----------|-------------|
| `time2screen()` | Interactive Shiny dashboard for screening time-series data |
