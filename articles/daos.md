# Getting started with daos

The **daos** package is a collection of utility functions built for
day-to-day statistical work. This vignette walks through every function
with short, self-contained examples.

------------------------------------------------------------------------

## Convenience shorthands

### `f()` — string interpolation

[`f()`](https://dataniel.github.io/daos/reference/f.md) is an alias for
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html). It
interpolates R expressions embedded in
[`{}`](https://rdrr.io/r/base/Paren.html) inside a string.

``` r
year <- 2026
f("Report for {year}")
#> Report for 2026
f("1 + 1 = {1 + 1}")
#> 1 + 1 = 2
```

### `nowf()` — formatted timestamp

[`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) returns
the current time as a formatted string. Useful for building timestamped
file names.

``` r
nowf()                  # default: YYYYMMDD
#> [1] "20260520"
nowf("%Y-%m-%d %H:%M")  # custom format
#> [1] "2026-05-20 22:22"
```

Combine the two for a quick timestamped path:

``` r
f("log/{nowf()}/pipeline.log")
```

### `quiet()` — suppress messages and warnings

``` r
quiet(message("this will not appear"))
quiet(warning("neither will this"))

# Useful when loading packages without the startup banner:
# quiet(library(tidyverse))
```

### `is_blank()` — comprehensive blank test

Unlike
[`rlang::is_empty()`](https://rlang.r-lib.org/reference/is_empty.html),
[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)
treats empty strings and all-`NA` vectors as blank.

``` r
is_blank(NULL)        # TRUE
#> [1] TRUE
is_blank(NA)          # TRUE
#> [1] TRUE
is_blank("")          # TRUE
#> [1] TRUE
is_blank(c(NA, NA))   # TRUE
#> [1] TRUE
is_blank(0)           # FALSE
#> [1] FALSE
is_blank("text")      # FALSE
#> [1] FALSE
```

### `%??%` — null-coalescing with blank detection

Returns the right-hand side whenever the left-hand side is blank (using
the same logic as
[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)).

``` r
NULL %??% "default"
#> [1] "default"
NA   %??% 0
#> [1] 0
""   %??% "unknown"
#> [1] "unknown"
42   %??% 99          # returns 42
#> [1] 42
```

### `%like%` — regex matching with NA preservation

`%like%` wraps [`grepl()`](https://rdrr.io/r/base/grep.html) but keeps
`NA` values as `NA` rather than converting them to `FALSE`.

``` r
c("sedan", "SUV", NA, "truck") %like% "^S"
#> [1] FALSE  TRUE    NA FALSE

# In a dplyr pipeline:
filter(ggplot2::mpg, model %like% "\\d+") |>
  count(model)
#> # A tibble: 19 × 2
#>    model                      n
#>    <chr>                  <int>
#>  1 4runner 4wd                6
#>  2 a4                         7
#>  3 a4 quattro                 8
#>  4 a6 quattro                 3
#>  5 c1500 suburban 2wd         5
#>  6 caravan 2wd               11
#>  7 dakota pickup 4wd          9
#>  8 durango 4wd                7
#>  9 expedition 2wd             3
#> 10 explorer 4wd               6
#> 11 f150 pickup 4wd            7
#> 12 grand cherokee 4wd         8
#> 13 k1500 tahoe 4wd            4
#> 14 land cruiser wagon 4wd     2
#> 15 mountaineer 4wd            4
#> 16 navigator 2wd              3
#> 17 pathfinder 4wd             4
#> 18 ram 1500 pickup 4wd       10
#> 19 toyota tacoma 4wd          7
```

------------------------------------------------------------------------

## File workflows

### `read_files()` — validate, read, and collect

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
expands [glue syntax](https://glue.tidyverse.org/) in path strings,
aborts immediately if any file is missing, and reads all files with
automatic format detection. A single path returns the object directly;
multiple paths return a named list with a progress bar.

``` r
# Single file (returns object directly):
df <- read_files("data/results.parquet")

# Multiple files with glue expansion — returns a named list:
lst <- read_files("data/dat{0:9}.parquet", names = 0:9)
```

Supported formats: `csv`, `tsv`, `parquet`, `feather`, `xlsx`, `xls`,
`rds`, `sas7bdat`, `sav`, `por`, `xpt`, `dta`, `json`, `ndjson`,
`jsonl`, `yaml`, `yml`, `txt`.

Supply a custom reader to override auto-detection or add arguments:

``` r
read_files(
  "data/dat{0:9}.parquet",
  reader = \(x) arrow::read_parquet(x, col_select = 1:5)
)
```

### Binding into one tibble

Set `out = "bind"` to row-bind all files into a single tibble. A
`source` column records the origin of each row. Column types are always
reconciled automatically.

``` r
df <- read_files("data/dat{0:9}.parquet", names = 0:9, out = "bind")
```

### Unpacking into individual variables

Set `out = "unpack"` to assign each file as its own named variable in
the calling environment:

``` r
read_files("data/dat{0:9}.parquet", names = paste0("dat", 0:9), out = "unpack")
# dat0, dat1, ..., dat9 are now in your environment
```

### `summon()` — retrieve objects by name pattern

Collect objects whose names match a regex back into a list:

``` r
dat1 <- data.frame(x = 1)
dat2 <- data.frame(x = 2)
dat3 <- data.frame(x = 3)

result <- summon("^dat\\d+$")
names(result)
#> [1] "dat1" "dat2" "dat3"
```

### `read_ta()` — read Greenlandic TA files

For Greenlandic TA files:

``` r
df <- read_ta("ta.file")
```

------------------------------------------------------------------------

## Data inspection

### `view_types()` — compare column types across data frames

[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
shows the
[`pillar::type_sum()`](https://pillar.r-lib.org/reference/type_sum.html)
type of each column for every dataset supplied. Invaluable before joins
or before binding with `read_files(out = "bind")`.

``` r
df_a <- data.frame(x = 1L,  y = "a", z = TRUE)
df_b <- data.frame(x = 1.0, y = "b", z = 1L)

# All columns:
view_types(df_a, df_b)
#> # A tibble: 3 × 3
#>   column df_a  df_b 
#>   <chr>  <chr> <chr>
#> 1 x      int   dbl  
#> 2 y      chr   chr  
#> 3 z      lgl   int
```

``` r
# Only columns where types differ:
view_types(df_a, df_b, diff = TRUE)
#> # A tibble: 2 × 3
#>   column df_a  df_b 
#>   <chr>  <chr> <chr>
#> 1 x      int   dbl  
#> 2 z      lgl   int
```

``` r
# Check that a specific column has the expected type:
view_types(df_a, df_b, focus = c(x = "int"))
#> # A tibble: 1 × 2
#>   column df_b 
#>   <chr>  <chr>
#> 1 x      dbl
# Returns 0 rows if all match, otherwise shows the offending datasets
```

### `size_env()` — object sizes in an environment

``` r
big   <- 1:1e6
small <- letters
size_env()        # all objects, largest first
#> # A tibble: 9 × 3
#>   name      size      pretty
#>   <chr>    <dbl> <fs::bytes>
#> 1 big    4000048       3.81M
#> 2 result    2648       2.59K
#> 3 small     1712       1.67K
#> 4 df_a      1064       1.04K
#> 5 df_b      1064       1.04K
#> 6 dat1       736         736
#> 7 dat2       736         736
#> 8 dat3       736         736
#> 9 year        56          56
size_env(n = 2)   # top 2 only
#> # A tibble: 2 × 3
#>   name      size      pretty
#>   <chr>    <dbl> <fs::bytes>
#> 1 big    4000048       3.81M
#> 2 result    2648       2.59K
```

------------------------------------------------------------------------

## Data validation

### `expect_empty()` — assert a data frame is empty

Use
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
as a checkpoint in a pipeline. It succeeds silently when the data frame
has no rows, warns when it has rows (unless `abort_msg` is set, in which
case it aborts).

``` r
# Success:
data.frame() |> expect_empty(success_msg = "All good — no rows")
#> ✔ All good — no rows

# Warning:
filter(ggplot2::mpg, cyl < 0) |>
  expect_empty(warn_msg = "Unexpected: negative cylinder count")
#> ✔ The dataset is empty.
```

``` r
# Hard error:
filter(dplyr::starwars, height < 0) |>
  expect_empty(abort_msg = "Impossible: negative height")
```

The `log` argument writes a timestamped entry to a file — useful in
automated pipelines where you want a minimal audit trail:

``` r
log_path <- f("log/{nowf()}/checks.log")
checker  <- purrr::partial(expect_empty, log = log_path)

filter(dplyr::starwars, name == "Harry Potter") |>
  checker(success_msg = "No fictional characters")

filter(dplyr::starwars, height > 250) |>
  checker(warn_msg = "Unusually tall characters found")
```

### `flag_duplicates()` — detect and label duplicate rows

[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
prepends two columns: `isdup` (logical) and `dupid` (an integer group
identifier, `0` for unique rows).

``` r
flag_duplicates(ggplot2::mpg)
#> # A tibble: 234 × 13
#>    isdup dupid manufacturer model      displ  year   cyl trans drv     cty   hwy
#>    <lgl> <int> <chr>        <chr>      <dbl> <int> <int> <chr> <chr> <int> <int>
#>  1 FALSE     0 audi         a4           1.8  1999     4 auto… f        18    29
#>  2 FALSE     0 audi         a4           1.8  1999     4 manu… f        21    29
#>  3 FALSE     0 audi         a4           2    2008     4 manu… f        20    31
#>  4 FALSE     0 audi         a4           2    2008     4 auto… f        21    30
#>  5 FALSE     0 audi         a4           2.8  1999     6 auto… f        16    26
#>  6 FALSE     0 audi         a4           2.8  1999     6 manu… f        18    26
#>  7 FALSE     0 audi         a4           3.1  2008     6 auto… f        18    27
#>  8 FALSE     0 audi         a4 quattro   1.8  1999     4 manu… 4        18    26
#>  9 FALSE     0 audi         a4 quattro   1.8  1999     4 auto… 4        16    25
#> 10 FALSE     0 audi         a4 quattro   2    2008     4 manu… 4        20    28
#> # ℹ 224 more rows
#> # ℹ 2 more variables: fl <chr>, class <chr>
```

``` r
# Check specific columns:
flag_duplicates(ggplot2::mpg, manufacturer, model, year) |>
  filter(isdup) |>
  arrange(dupid)
#> # A tibble: 227 × 13
#>    isdup dupid manufacturer model      displ  year   cyl trans drv     cty   hwy
#>    <lgl> <int> <chr>        <chr>      <dbl> <int> <int> <chr> <chr> <int> <int>
#>  1 TRUE      1 audi         a4           1.8  1999     4 auto… f        18    29
#>  2 TRUE      1 audi         a4           1.8  1999     4 manu… f        21    29
#>  3 TRUE      1 audi         a4           2.8  1999     6 auto… f        16    26
#>  4 TRUE      1 audi         a4           2.8  1999     6 manu… f        18    26
#>  5 TRUE      2 audi         a4           2    2008     4 manu… f        20    31
#>  6 TRUE      2 audi         a4           2    2008     4 auto… f        21    30
#>  7 TRUE      2 audi         a4           3.1  2008     6 auto… f        18    27
#>  8 TRUE      3 audi         a4 quattro   1.8  1999     4 manu… 4        18    26
#>  9 TRUE      3 audi         a4 quattro   1.8  1999     4 auto… 4        16    25
#> 10 TRUE      3 audi         a4 quattro   2.8  1999     6 auto… 4        15    25
#> # ℹ 217 more rows
#> # ℹ 2 more variables: fl <chr>, class <chr>
```

Combine with
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
for a pipeline validation gate:

``` r
ggplot2::mpg |>
  flag_duplicates() |>
  filter(isdup) |>
  expect_empty(warn_msg = "Duplicate rows detected")
#> Warning: Duplicate rows detected
```

------------------------------------------------------------------------

## Data manipulation

### `split_by()` — split a data frame into a named list

[`split_by()`](https://dataniel.github.io/daos/reference/split_by.md) is
a named version of
[`dplyr::group_split()`](https://dplyr.tidyverse.org/reference/group_split.html):

``` r
parts <- split_by(ggplot2::mpg, manufacturer)
names(parts)[1:5]
#> [1] "audi"      "chevrolet" "dodge"     "ford"      "honda"
head(parts[["audi"]])
#> # A tibble: 6 × 11
#>   manufacturer model displ  year   cyl trans      drv     cty   hwy fl    class 
#>   <chr>        <chr> <dbl> <int> <int> <chr>      <chr> <int> <int> <chr> <chr> 
#> 1 audi         a4      1.8  1999     4 auto(l5)   f        18    29 p     compa…
#> 2 audi         a4      1.8  1999     4 manual(m5) f        21    29 p     compa…
#> 3 audi         a4      2    2008     4 manual(m6) f        20    31 p     compa…
#> 4 audi         a4      2    2008     4 auto(av)   f        21    30 p     compa…
#> 5 audi         a4      2.8  1999     6 auto(l5)   f        16    26 p     compa…
#> 6 audi         a4      2.8  1999     6 manual(m5) f        18    26 p     compa…
```

Multiple grouping columns are joined with `.sep`:

``` r
parts2 <- split_by(ggplot2::mpg, cyl, drv, .sep = "-")
names(parts2)[1:4]
#> [1] "4-4" "4-f" "5-f" "6-4"
```

### `find_signs()` — reconcile accounting line items

[`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md)
uses a *meet-in-the-middle* algorithm to find the sign assignment (`+1`,
`-1`, or `0`) for a set of values such that their signed sum equals a
specified total. Useful when importing accounting data where sign
conventions are unknown.

``` r
items <- data.frame(
  label = c("revenue", "costs", "tax", "total"),
  value = c(1000, 400, 100, 500)
)

find_signs(items, label, value, total_label = "total")
#> # A tibble: 0 × 0
```

You can pin known signs and allow at most `max_zeros` items to be
excluded:

``` r
find_signs(
  items,
  label, value,
  total_label = "total",
  positive    = "revenue",
  negative    = c("costs", "tax"),
  max_zeros   = 1L
)
```

------------------------------------------------------------------------

## Danish CPR numbers

### `cpr_info()` — extract birth date, age, sex, and validity

[`cpr_info()`](https://dataniel.github.io/daos/reference/cpr_info.md)
appends one or more derived columns to a data frame using official CPR
Register century-detection rules. Dashes and spaces are stripped
automatically; nine-digit numbers are zero-padded to recover values that
lost a leading zero in Excel.

``` r
df <- data.frame(
  pnr = c("1111111118", "111111-1118", "111111118"),
  stringsAsFactors = FALSE
)

cpr_info(df, pnr)
#>          pnr       bday age sex mod11 valid
#> 1 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 2 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 3 0111111118 1911-11-01 114   0 FALSE  TRUE
```

Choose a subset of columns and optionally rename them:

``` r
cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#>          pnr birth_date years_old
#> 1 1111111118 1911-11-11       114
#> 2 1111111118 1911-11-11       114
#> 3 0111111118 1911-11-01       114
```

A custom reference date shifts the age calculation:

``` r
cpr_info(df, pnr, add = "age", ref_date = "2000-01-01")
#>          pnr age
#> 1 1111111118  88
#> 2 1111111118  88
#> 3 0111111118  88
```

------------------------------------------------------------------------

## Interactive tools

### `track_last_df()` — auto-save the last printed data frame

Enable to automatically capture any data frame returned to the console
as `.last.df` in the global environment. Handy when you forget to assign
an intermediate result.

``` r
track_last_df()          # enable

dplyr::starwars |> head(3)
.last.df                 # the three-row data frame above

track_last_df(FALSE)     # disable
```

### `time2screen()` — Shiny time-series screening dashboard

[`time2screen()`](https://dataniel.github.io/daos/reference/time2screen.md)
launches an interactive Shiny app for reviewing time series group by
group. All columns that are not `x`, `y`, `series`, or excluded
automatically become dropdown filters. Navigate with the keyboard (`←` /
`→`) or click buttons. Press `Esc` to exit.

Requires `shiny` and `highcharter`.

``` r
library(shiny)
library(highcharter)

# Simple example — one line per group:
df <- expand.grid(
  year    = 2010:2020,
  country = c("DK", "SE", "NO", "FI")
)
df$gdp <- rnorm(nrow(df), mean = 300, sd = 30)

time2screen(df, x = year, y = gdp)

# With a series dimension for multiple lines per group:
ggplot2::economics_long |>
  time2screen(date, value, series = variable)
```
