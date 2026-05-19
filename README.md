# daos

[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

> **Experimental.** This package is a personal collection of utility functions
> that have grown out of day-to-day statistical work — things I kept wishing R
> had out of the box, patterns I found myself repeating, and new ideas I wanted
> to try out. Rather than letting them accumulate as loose scripts, I packaged
> them up properly with the help of [Claude Code](https://claude.ai/code) to
> get a solid starting point: documentation, tests, and a vignette from the
> start. Consider it a living experiment.

## Installation

```r
pak::pak("dataniel/daos")
```

Or from a local clone:

```r
devtools::install()
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

```r
# Use a fallback when a value is missing or empty
x <- NULL
x %??% "default"

# Regex that keeps NA as NA
c("apple", NA, "banana") %like% "^a"

# String interpolation
name <- "world"
f("Hello {name}")

# Timestamped file name
saveRDS(df, f("output_{nowf()}.rds"))
```

### File workflow

| Function | Description |
|----------|-------------|
| `read_files()` | Auto-detect format and read one or more files |
| `require_files()` | Validate paths (with glue expansion) before reading |
| `bind_files()` | Row-bind a list of data frames with helpful type-mismatch errors |
| `unpack_files()` | Assign list elements as individual variables |

```r
# Validate → read → combine
require_files("data/dat{0:9}.parquet") |>
  read_files() |>
  bind_files()

# Or unpack into separate variables
require_files("data/dat{0:9}.parquet") |>
  read_files() |>
  unpack_files()
```

### Data wrangling

| Function | Description |
|----------|-------------|
| `view_types()` | Compare column types across multiple data frames |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `expect_empty()` | Pipeline checkpoint — warn or abort if data frame is non-empty |
| `split_by()` | Split a data frame into a named list by grouping columns |

```r
# Check for type mismatches before binding
view_types(df1, df2, df3)

# Mark duplicate rows
flag_duplicates(df, id, date)

# Assert no unexpected rows survive a filter
df |>
  filter(status == "error") |>
  expect_empty("Unexpected errors found")

# Split by group
split_by(df, year, region)
```

### Environment

| Function | Description |
|----------|-------------|
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `size_env()` | Show object sizes in an environment |
| `track_last_df()` | Auto-save the last printed data frame as `.last.df` |

```r
# Collect all data frames loaded earlier
summon("^dat\\d+$")

# See what's eating memory
size_env()

# Auto-capture the last printed data frame
track_last_df()  # call once at session start
df               # print as usual — now available as .last.df
```

### Domain-specific

| Function | Description |
|----------|-------------|
| `cpr_info()` | Extract birth date, age, sex, and validity from Danish CPR numbers |
| `read_ta()` | Read Greenlandic TA files |
| `find_signs()` | Find sign assignments that reconcile a set of values to a total |

```r
# Parse CPR numbers
df <- data.frame(pnr = c("1111111118", "111111-1118"))
cpr_info(df, pnr)

# Read a TA file
df <- read_ta("ta.file")

# Find which items should be positive/negative to sum to a total
items <- data.frame(
  label = c("revenue", "costs", "depreciation", "total"),
  value = c(100, 40, 10, 50)
)
find_signs(items, label, value, total_label = "total")
```

### Interactive

| Function | Description |
|----------|-------------|
| `time2screen()` | Interactive Shiny dashboard for screening time-series data |

```r
ggplot2::economics_long |>
  time2screen(x = date, y = value, .exclude = value01)
```

## Vignette

To build the vignette, install with:

```r
remotes::install_github("dataniel/daos", build_vignettes = TRUE)
```

Then open it with:

```r
vignette("daos")
```
