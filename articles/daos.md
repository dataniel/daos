# Getting started with daos

The **daos** package is a collection of utility functions built for
day-to-day statistical work. This vignette walks through every function
with short, self-contained examples.

Five bodies of work that started here have since grown into packages of
their own, and are not covered below:
[taskr](https://github.com/dataniel/taskr) for task management,
[statbank](https://github.com/dataniel/statbank) for the Greenland and
Faroese statbanks, [cvrr](https://github.com/dataniel/cvrr) for
published Danish annual reports,
[taxmill](https://github.com/dataniel/taxmill) for milling PDF financial
statements into data, and [pathr](https://github.com/dataniel/pathr) for
the file browser and the RStudio addins that take the friction out of
Windows paths. None of them depends on daos, or daos on them.

------------------------------------------------------------------------

## Convenience shorthands

### `f()`: string interpolation

[`f()`](https://dataniel.github.io/daos/reference/f.md) is a short alias
for [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html),
inspired by Python’s f-string syntax. The name is not self-explanatory,
but it is fast to type and stays out of the way in a pipeline.

``` r
year <- 2026
f("Report for {year}")
#> Report for 2026
f("1 + 1 = {1 + 1}")
#> 1 + 1 = 2
```

### `nowf()`: formatted timestamp

[`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) combines
[`format()`](https://rdrr.io/r/base/format.html) and
[`Sys.time()`](https://rdrr.io/r/base/Sys.time.html) in a single call,
so you can timestamp an export inline without stopping to look up the
`format(Sys.time(), ...)` signature.

``` r
nowf()                  # default: YYYYMMDD
#> [1] "20261027"
nowf("%Y-%m-%d %H:%M")  # custom format
#> [1] "2026-10-27 18:28"
```

A typical use is timestamping an export file:

``` r
iris |>
  writexl::write_xlsx(f("iris_{nowf('%Y%B')}.xlsx"))
```

### `shh()`: suppress messages and warnings

A shorthand for `suppressMessages(suppressWarnings(...))`. Useful when
you are tired of tidyverse startup banners, or when an R script runs as
a CLI tool (e.g. with `rapp`) or in a presentation tool like
`presenterm`, where console output has to be clean. The odd name is on
purpose: a function called `quiet` is one masking conflict away from
trouble.

``` r
shh(message("this will not appear"))
shh(warning("neither will this"))
```

### `is_blank()`: comprehensive blank test

[`is.na()`](https://rdrr.io/r/base/NA.html) only catches `NA`, and
[`rlang::is_empty()`](https://rlang.r-lib.org/reference/is_empty.html)
only catches `NULL` and zero-length vectors.
[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)
covers all three plus empty strings, which is handy when validating
input that can arrive in any of these forms.

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

### `%??%`: null-coalescing with blank detection

Like `rlang::%||%` but uses
[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)
instead of [`is.null()`](https://rdrr.io/r/base/NULL.html), so it also
triggers on `NA`, `""`, and empty vectors.

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

### `%like%`: regex matching with NA preservation

`%like%` is a more readable replacement for `str_detect()`. The infix
form reads naturally in a
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) call,
and unlike [`grepl()`](https://rdrr.io/r/base/grep.html), `NA` values
stay `NA` instead of being coerced to `FALSE`. That matters when
filtering on optional fields.

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

### `read_files()`: validate, read, and collect

Reading a set of files normally takes a small pipeline:
[`list.files()`](https://rdrr.io/r/base/list.files.html), a loop or
[`purrr::map()`](https://purrr.tidyverse.org/reference/map.html), and
manual naming.
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
does it in one call and handles path expansion, existence checks, format
detection, and naming along the way.

A single path returns the object directly; multiple paths return a named
list with a progress bar.

``` r
# Single file (returns object directly):
df <- read_files("data/results.parquet")

# Multiple files with glue expansion:
lst <- read_files("data/dat{0:9}.parquet", names = 0:9)
```

Supported formats: `csv`, `tsv`, `parquet`, `feather`, `xlsx`, `xls`,
`rds`, `sas7bdat`, `sav`, `por`, `xpt`, `dta`, `json`, `ndjson`,
`jsonl`, `yaml`, `yml`, `txt`.

In practice,
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
works best when data production is consistent: same formats, same column
names, same types across files. If
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
handles a set of files without warnings, the workflow is in order. When
it warns about type mismatches, something has changed upstream. There is
a separate article about this way of working, and about using
[`expectr::view_types()`](https://dataniel.github.io/expectr/reference/view_types.html)
when files refuse to stack:
[`vignette("read-files")`](https://dataniel.github.io/daos/articles/read-files.md).

Supply a custom reader to override auto-detection or add arguments:

``` r
read_files(
  "data/dat{0:9}.parquet",
  reader = \(x) arrow::read_parquet(x, col_select = 1:5)
)
```

**Column name casing**

By default, column names are converted to lowercase after reading
(`.lowercase = TRUE`). Set `.lowercase = FALSE` to preserve original
casing.

**Binding into one tibble**

Set `out = "bind"` to row-bind all files. Use `.id` to track the origin
of each row. When `names` is a numeric vector (e.g. years), the `.id`
column will also be numeric.

``` r
read_files(
  "data/dat{2020:2024}.parquet",
  names = 2020:2024,
  out   = "bind",
  .id   = "year"
)
```

If column types differ across files, a warning is issued and types are
reconciled with
[`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html).
The `.id` column is always excluded from this reconciliation.

**Unpacking into individual variables**

Set `out = "unpack"` to assign each file as its own named variable in
the calling environment. By default,
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
aborts if any name already exists. Set `.overwrite = TRUE` to allow
overwriting.

``` r
read_files("data/dat{0:9}.parquet", names = paste0("dat", 0:9), out = "unpack")
```

### `summon()`: retrieve objects by name pattern

A regex-based alternative to [`ls()`](https://rdrr.io/r/base/ls.html) +
[`mget()`](https://rdrr.io/r/base/get.html):

``` r
mget(ls(pattern = "dat\\d"))   # base R
summon("dat\\d")               # daos
```

[`summon()`](https://dataniel.github.io/daos/reference/summon.md) pairs
naturally with `out = "unpack"` to collect a family of objects back into
a list:

``` r
dat1 <- data.frame(x = 1)
dat2 <- data.frame(x = 2)
dat3 <- data.frame(x = 3)

result <- summon("^dat\\d+$")
names(result)
#> [1] "dat1" "dat2" "dat3"
```

### `read_access()`: read from a Microsoft Access database

Connects to an `.mdb` or `.accdb` file via ODBC, executes a SQL query,
and returns the result as a tibble. Requires the `DBI` and `odbc`
packages and a Microsoft Access ODBC driver.

The `verbosity` argument controls output:

- `"compact"` (default): one line per file, best when looping
- `"full"`: header, spinners, and summary, best for single files
- `"quiet"`: no output

``` r
# Full output for interactive use:
df <- read_access("data/sales.mdb", "SELECT * FROM Customers",
                  verbosity = "full")

# Loop over many databases quietly:
files <- list.files("data", pattern = "\\.mdb$", full.names = TRUE)
results <- lapply(files, \(f) read_access(f, "SELECT * FROM Sales"))
```

### `write_excel()`: write presentable Excel files

This function exists because a plain data export is hard to read for the
people the file is meant for. The complaint from a colleague who works
with macroeconomic statistics was concrete: no frozen header, no
thousand separators, no rounding.
[`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
is fast but writes exactly such unformatted files, and `openxlsx2` can
do all the styling but wants a workbook object, worksheets, styles, and
a save call.
[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
sits in between: one call, with defaults that make the file presentable.

- Numeric columns with at least one value ≥ 1,000 are formatted with a
  thousand separator and no displayed decimals (`#,##0`); the underlying
  values are preserved. Use `digits = 2` for two displayed decimals, or
  `digits = NULL` to disable automatic numeric formatting. This applies
  to columns with an absolute value of at least 1,000.
- Year-like columns are excluded automatically: a numeric column where
  every value is a whole number between 1800 and 2200 is assumed to hold
  years, so `2020` is not displayed as `2.020`. Disable with
  `detect_years = FALSE`, and use `skip_fmt` for columns the heuristic
  cannot guess (e.g. numeric period codes like `202001`).
- `NA` values appear as blank cells.
- The header row is bold.
- The first row is frozen (can be turned off with
  `freeze_header = FALSE`).

Only `.xlsx` can be written. The old binary `.xls` format is not
supported, and a non-`.xlsx` path fails early instead of producing a
file Excel will complain about.

**Writing a new file**

Pass a data frame or a named list of data frames. The default
`mode = "new"` fails if the file already exists. Use
`mode = "overwrite"` to replace the entire workbook.

``` r
# Single data frame: sheet name defaults to "Sheet1"
write_excel(mtcars, "output.xlsx")

# Named list: each element becomes a sheet
write_excel(
  list(Cars = mtcars, Iris = iris),
  "output.xlsx"
)
```

**Sheet naming**

Sheet names come from the list names. Unnamed elements get default names
(`"Sheet1"`, `"Sheet2"`, …). Mixed naming is also fine:

``` r
# "Hoved" is explicit; second sheet becomes "Sheet2"
write_excel(list(Hoved = mtcars, iris), "output.xlsx")
```

**Appending sheets to an existing file**

`mode = "append"` adds sheets to an existing file and fails on name
collisions. Use `mode = "replace"` to replace matching sheets and add
any new ones. Names are matched ignoring case; replaced sheets keep
their position, and other sheets are retained. Both modes require an
existing file and operate on whole sheets, not individual rows.

``` r
write_excel(list(Hoved = mtcars), "output.xlsx")
write_excel(list(Bilag = iris), "output.xlsx", mode = "append")
write_excel(list(Hoved = mtcars), "output.xlsx", mode = "replace")
```

**Other options**

``` r
# Insert as an Excel table (filter arrows, banded rows)
write_excel(mtcars, "output.xlsx", as_table = TRUE)

# Exclude columns from the #,##0 format
write_excel(mtcars, "output.xlsx", skip_fmt = "hp")
```

### `read_ta()` / `write_ta()`: read and write Greenlandic TA files

``` r
df <- read_ta("ta.file")
write_ta(df, "ta.file")
```

[`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md)
only writes what
[`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)
reads back unchanged. Values that would not fit their fixed-width field,
or would lose decimals, stop with an error that lists them, so no file
with shifted fields is written.

### `read_ta2()` / `write_ta2()`: the new TA layout

``` r
df <- read_ta2("ta.file")
write_ta2(df, "ta.file")
```

The new TA system uses a 140-character layout with nine columns. The `2`
functions handle it with the same guarantee as
[`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md);
the old pair is kept for the transition and for old files.
[`read_ta2()`](https://dataniel.github.io/daos/reference/read_ta2.md)
refuses lines shorter than 140 characters, so an old-layout file is
never read into the wrong columns.

------------------------------------------------------------------------

## Data validation: the expectr package

The validation checkpoints,
[`expect_empty()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
[`expect_none()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
[`expect_unique()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
[`expect_balanced()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
[`expect_no_overlap()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
and
[`tally_violations()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
and the helpers
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
and
[`view_types()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
have moved to their own package,
[expectr](https://github.com/dataniel/expectr). They share an engine and
a contract the rest of daos does not: each states an expectation about
data as “the set of violations must be empty”.

daos still forwards each of them to expectr, so existing scripts keep
working, old options such as `daos.check_log` included. New code should
load expectr directly:

``` r
library(expectr)

read_files("data/dat{2020:2023}.parquet", names = 2020:2023) |>
  view_types(diff = TRUE) |>
  expect_empty(warn_msg = "The files do not bind")
```

See
[`vignette("expectr", package = "expectr")`](https://dataniel.github.io/expectr/articles/expectr.html).

------------------------------------------------------------------------

## Data manipulation

### `drop_empty_rows()` and `drop_empty_cols()`: selective removal

Choose which columns determine whether a row is empty, so an ID or
metadata column does not keep an otherwise empty observation. Selection
works like
[`select()`](https://dplyr.tidyverse.org/reference/select.html): names,
ranges,
[`starts_with()`](https://tidyselect.r-lib.org/reference/starts_with.html),
`where(is.numeric)`, and
[`all_of()`](https://tidyselect.r-lib.org/reference/all_of.html). With
no selection, every column is inspected.

``` r
df <- tibble::tibble(
  id = 1:3,
  score_a = c(1, NA, NA),
  score_b = c(NA_real_, NA_real_, NA_real_),
  comment = c("ok", "", "  ")
)

# Inspect the score columns; keep every column in retained rows.
drop_empty_rows(df, starts_with("score_"))
#> # A tibble: 1 × 4
#>      id score_a score_b comment
#>   <int>   <dbl>   <dbl> <chr>  
#> 1     1       1      NA ok

# Only numeric columns are candidates for removal; id is not empty.
drop_empty_cols(df, where(is.numeric))
#> # A tibble: 3 × 3
#>      id score_a comment
#>   <int>   <dbl> <chr>  
#> 1     1       1 "ok"   
#> 2     2      NA ""     
#> 3     3      NA "  "

# Include empty and whitespace-only text, without modifying retained values.
drop_empty_rows(df, comment, blank = TRUE)
#> # A tibble: 1 × 4
#>      id score_a score_b comment
#>   <int>   <dbl>   <dbl> <chr>  
#> 1     1       1      NA ok

# Combine row and column removal explicitly.
df |> drop_empty_rows(starts_with("score_")) |> drop_empty_cols()
#> # A tibble: 1 × 3
#>      id score_a comment
#>   <int>   <dbl> <chr>  
#> 1     1       1 ok
```

By default, only missing values (`NA` and `NaN`) count as empty.
`blank = TRUE` also handles blank character values and factor labels.
Zero and `FALSE` always count as data. A row is removed only when
**all** selected values are empty. Column removal only affects the
selected columns.

An empty selection changes nothing. Zero-row inputs retain their column
schema; zero-column inputs retain their rows. Grouped data is assessed
over the whole input, and grouping metadata is updated when columns are
removed.

### `split_by()`: split a data frame into a named list

[`dplyr::group_split()`](https://dplyr.tidyverse.org/reference/group_split.html)
returns an unnamed list.
[`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)
adds names derived from the grouping values, making it straightforward
to index by group:

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

### `spells_to_panel()`: from spells to a yearly panel

Registers often store spells: one row per education, address or benefit
period, with a start, an end and a status.
[`spells_to_panel()`](https://dataniel.github.io/daos/reference/spells_to_panel.md)
turns them into one row per unit and year (or
`by = "quarter"`/`"month"`), with the status at primo and ultimo. By
default primo is the previous ultimo, so primo 2021 is the status on 31
December 2020.

In an education register the status is the *outcome* of the spell,
passed or dropped out. With `status_is = "outcome"`, a running spell
shows as `ongoing` and the outcome applies from the end date until a new
spell starts:

``` r
education <- data.frame(
  cpr    = c("a", "a", "b"),
  start  = as.Date(c("2018-08-15", "2021-08-15", "2019-08-15")),
  end    = as.Date(c("2021-06-20", NA,           "2020-03-01")),
  status = c("passed", "in progress", "dropped out")
)

education |>
  spells_to_panel(cpr, start, end, status,
                  from = 2018, to = 2022,
                  status_is = "outcome", ongoing = "in progress")
#> # A tibble: 10 × 4
#>    cpr    year primo       ultimo     
#>    <chr> <int> <chr>       <chr>      
#>  1 a      2018 NA          in progress
#>  2 a      2019 in progress in progress
#>  3 a      2020 in progress in progress
#>  4 a      2021 in progress in progress
#>  5 a      2022 in progress in progress
#>  6 b      2018 NA          NA         
#>  7 b      2019 NA          in progress
#>  8 b      2020 in progress dropped out
#>  9 b      2021 dropped out dropped out
#> 10 b      2022 dropped out dropped out
```

With the default `status_is = "state"`, the status holds for the whole
spell (enrolled, on leave) and is `NA` outside spells. `from` and `to`
give every unit the same window, which makes a balanced panel. Without
them, each unit runs from its first start to its last end. Dates are
handled as integer days, and one compiled pass over the sorted spells
does the work, so millions of spells take seconds.

### `add_spell_status()`: status from spells on a panel you already have

Often the panel exists already, e.g. a population with one row per
person and year, and the spells should only add a status to it. A
`left_join(join_by(between()))` does that until the data gets messy:
overlapping spells duplicate rows, and an ongoing spell with no end
matches nothing.
[`add_spell_status()`](https://dataniel.github.io/daos/reference/add_spell_status.md)
keeps the rows of the panel exactly as they are and uses the rules of
[`spells_to_panel()`](https://dataniel.github.io/daos/reference/spells_to_panel.md):

``` r
population <- data.frame(cpr  = c("a", "a", "b", "c"),
                         year = c(2020, 2021, 2020, 2020))

population |>
  add_spell_status(education, cpr, year, start, end, status,
                   status_is = "outcome", ongoing = "in progress")
#>   cpr year status_primo status_ultimo
#> 1   a 2020  in progress   in progress
#> 2   a 2021  in progress   in progress
#> 3   b 2020  in progress   dropped out
#> 4   c 2020         <NA>          <NA>
```

A Date column in `at` gives the status on that day instead, e.g. the day
of a diagnosis. Use `when = "ultimo"` for a single column, `name` to
choose its name, and `overlap = "error"` to stop when spells overlap.

------------------------------------------------------------------------

## Domain-specific

### `clean_cpr()` / `clean_cvr()`: standardise identifier columns

Identifiers rarely arrive in one consistent shape: `111111-1118`,
`12 34 56 78`, `DK12345678`, or a nine-digit CPR that lost its leading
zero in Excel. Before a join, both sides need the same form, and that is
all these two functions do. They take a vector and return a vector, so
the natural place for them is inside a
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html):

``` r
clean_cpr(c("111111-1118", "101004007", "1111111118"))
#> [1] "1111111118" "0101004007" "1111111118"
clean_cvr(c("DK12345678", "12 34 56 78", "12345678"))
#> [1] "12345678" "12345678" "12345678"
```

The two differ on one point.
[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
zero-pads nine-digit values, because birth days 01 to 09 mean that a
third of all CPR numbers start with a zero, which Excel drops.
[`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md)
never adds a digit: a seven-digit CVR cannot be told apart from a typo,
and padding it would let a malformed number slip past a later
`cvr %like% "^\\d{8}$"` checkpoint.

Neither function validates. Malformed values come back cleaned but still
visibly malformed. Validation is
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)’s
job (below), or a checkpoint from expectr.

### `format_db07()`: choose the format of DB07 industry codes

DB07 industry codes appear both as `011100` and `01.11.00` depending on
the source.
[`format_db07()`](https://dataniel.github.io/daos/reference/format_db07.md)
automatically handles mixed input with dots, whitespace, or digits only.
Choose `"dotted"` (the default) or `"compact"` output without specifying
the input format. Any aggregation level works:

``` r
format_db07(c("011100", "01.1100", "0111", "011"))
#> [1] "01.11.00" "01.11.00" "01.11"    "01.1"
format_db07(c("011100", "01.11.00", "01 11 00"), format = "compact")
#> [1] "011100" "011100" "011100"
```

Like the `clean_*` functions,
[`format_db07()`](https://dataniel.github.io/daos/reference/format_db07.md)
never invents digits: a code that lost its leading zero in Excel is
ambiguous (`111` could be group `11.1` or class `01.11`), so keep
industry codes as character columns.

### `db_label()`: add Danish industry labels

Use
[`db_label()`](https://dataniel.github.io/daos/reference/db_label.md) to
add a label column from a DB code. Always specify `version = "DB07"` or
`version = "DB25"`; identical codes can have different meanings in the
two classifications.

``` r
df <- data.frame(dbkode = c("011200", "01.49.10", NA))
df |> dplyr::mutate(branche_label = db_label(dbkode, version = "DB07"))
#>     dbkode   branche_label
#> 1   011200 Dyrkning af ris
#> 2 01.49.10        Kenneler
#> 3     <NA>            <NA>
db_label(c("A", "01", "01.1", "01.11"), version = "DB25")
#> [1] "LANDBRUG, JAGT, SKOVBRUG OG FISKERI"                              
#> [2] "Plante- og husdyravl, jagt og serviceydelser i forbindelse hermed"
#> [3] "Dyrkning af etårige afgrøder"                                     
#> [4] "Dyrkning af korn (undtagen ris), bælgfrugter og olieholdige frø"
```

Labels come from the bundled DST tables and work offline. Input can
contain dots or whitespace. Unknown codes return `NA` with a warning;
missing values stay missing. Keep leading zeroes in character codes.

### Convert industry codes between DB07 and DB25

For mixed data, inspect the source codes before converting:

``` r
inspect_db(c("014910", "014800", "253000", "011200", NA))
#> # A tibble: 5 × 5
#>   input  code   status    label_db07                                  label_db25
#>   <chr>  <chr>  <chr>     <chr>                                       <chr>     
#> 1 014910 014910 db07_only Kenneler                                    NA        
#> 2 014800 014800 db25_only NA                                          Avl af an…
#> 3 253000 253000 both      Fremstilling af dampkedler undtagen centra… Fremstill…
#> 4 011200 011200 both      Dyrkning af ris                             Dyrkning …
#> 5 NA     NA     missing   NA                                          NA
```

`db07_only` and `db25_only` indicate membership in just one
classification. `both` means the version cannot be determined from the
code alone: `253000` has different meanings in DB07 and DB25. Both
labels are returned for review. Identical labels also leave the version
unresolved. Use source metadata and the original industry text and time
context to investigate these rows. The inspection supports full
six-digit codes only.

[`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
and
[`convert_db25_to_db07()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
use bundled keys from [Statistics
Denmark](https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende)
(source page updated 26 February 2026), so no internet connection is
needed. Both accept full six-digit codes with or without dots and
whitespace:

``` r
convert_db07_to_db25(c("011100", "01.49.10", NA))
#> [1] "01.11.00" "01.48.00" NA
convert_db25_to_db07("25.30.00", format = "compact")
#> [1] "254000"
```

By default, a code with multiple possible destinations returns `NA` with
a warning. To choose DST’s simplified mapping explicitly:

``` r
convert_db07_to_db25("01.19.00", method = "simple")
#> [1] "01.19.00"
convert_db25_to_db07("01.48.00", method = "simple")
#> [1] "01.49.10"
```

The simplified matrices are specific to each direction and use numbers
of units, not economic activity. They are approximate and should not be
used as weights to distribute turnover. A round trip need not recover
the original code. Invalid lengths and unknown codes return `NA` with a
warning; missing values remain missing. Leading zeroes are not guessed.

### `add_cpr_info()`: add birth date, age, sex, and validity

[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
appends selected information while preserving the original CPR column.
Dashes, spaces, and lost leading zeroes are handled internally. Use
[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
explicitly if you also want to standardise the source column.

Both functions share the same native cleaning rules.
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
parses each CPR once for all requested outputs, including multiple age
calculations. You do not need a separate cleaning step just to calculate
CPR information. Use an explicit cleaning step when the identifier will
also be used for joins or export:

``` r
df |>
  dplyr::mutate(pnr = clean_cpr(pnr)) |>
  add_cpr_info(pnr, age(year), sex, bday)
```

[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
is idempotent: cleaning again gives the same values. Already
standardised character vectors are returned without a replacement
vector.

Without selections, the function adds `bday`, `age`, `sex`, `mod11`, and
`valid`. Bare `age` and
[`age()`](https://dataniel.github.io/daos/reference/age.md) use today’s
date; explicit references make analysis reproducible.

``` r
df <- data.frame(
  pnr = c("1111111118", "111111-1118", "111111118"),
  year = c(2024L, 2025L, 2026L)
)
add_cpr_info(df, pnr)
#>           pnr year       bday age sex mod11 valid
#> 1  1111111118 2024 1911-11-11 114   0  TRUE  TRUE
#> 2 111111-1118 2025 1911-11-11 114   0  TRUE  TRUE
#> 3   111111118 2026 1911-11-01 114   0 FALSE  TRUE
add_cpr_info(df, pnr, sex, birth_date = bday)
#>           pnr year sex birth_date
#> 1  1111111118 2024   0 1911-11-11
#> 2 111111-1118 2025   0 1911-11-11
#> 3   111111118 2026   0 1911-11-01
```

Write `output_name = calculation` to rename a result. Each age
calculation has its own reference, so several ages can be added in one
call:

``` r
df |>
  add_cpr_info(
    pnr,
    primoalder = age(year),
    medioalder = age(year, "medio"),
    ultimoalder = age(year, "ultimo"),
    sex,
    bday
  )
#>           pnr year primoalder medioalder ultimoalder sex       bday
#> 1  1111111118 2024        112        112         113   0 1911-11-11
#> 2 111111-1118 2025        113        113         114   0 1911-11-11
#> 3   111111118 2026        114        114         115   0 1911-11-01
```

`age(year)` defaults to `"primo"` with `primo = "previous_ultimo"` (31
December of the previous year); `"medio"` means 1 July and `"ultimo"`
means 31 December. `year` can be a scalar, a column, or an expression
evaluated in the original input data.

This default makes opening ages equal to the previous year’s closing
ages. It can also be written explicitly:

``` r
add_cpr_info(df, pnr, primoalder = age(year, primo = "previous_ultimo"))
#>           pnr year primoalder
#> 1  1111111118 2024        112
#> 2 111111-1118 2025        113
#> 3   111111118 2026        114
```

Someone born on 1 January 2000 is then 0 in counting year 2001;
`age(year, primo = "jan1")` instead includes that day’s birthday and
gives 1.

For a specific date, use `age(date = ...)` with a Date or ISO date
string. Supply one reference for all rows or one per row. Missing
references give missing ages. Use `.env$name` to explicitly access a
caller variable when a column has the same name.

``` r
add_cpr_info(df, pnr, alder = age(date = "2025-07-01"))
#>           pnr year alder
#> 1  1111111118 2024   113
#> 2 111111-1118 2025   113
#> 3   111111118 2026   113
df$reference <- as.Date(paste0(df$year, "-01-01"))
add_cpr_info(df, pnr, alder = age(date = reference))
#>           pnr year  reference alder
#> 1  1111111118 2024 2024-01-01   112
#> 2 111111-1118 2025 2025-01-01   113
#> 3   111111118 2026 2026-01-01   114
```

Existing output names cause an error with guidance to rename the
selection or use `overwrite = TRUE`. Duplicate output names are always
an error, and the source CPR column cannot be overwritten.

`valid` means ten digits encoding a real calendar date, not confirmation
that the CPR number was assigned. Missing and invalid CPR values give
`valid = FALSE`. `mod11` is an independent checksum and is not part of
`valid`. Choose `mod11` explicitly when selecting outputs if you need
it.

The former `add`, `ref_date`, `year`, and `at` arguments are replaced by
selections and
[`age()`](https://dataniel.github.io/daos/reference/age.md). For
example, `add = c(alder = "age"), year = year` becomes
`alder = age(year)`. The source CPR column is now preserved.

Age counts completed calendar years, not elapsed days divided by 365.25.
For a person born on 29 February, age increases on 29 February in leap
years and on 1 March in non-leap years. For a birth date of 29 February
2000:

| Reference date | Age |
|----------------|----:|
| 2024-02-28     |  23 |
| 2024-02-29     |  24 |
| 2024-03-01     |  24 |
| 2025-02-28     |  24 |
| 2025-03-01     |  25 |

`age(2024)` means age on 31 December 2023. by default, giving age 23 in
this example.

## Interactive tools

### `screen_timeseries()`: interactive time-series screening

It is hard to get as close to data in a console as in Excel, where the
feedback is immediate and visual.
[`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
is an attempt to bridge that gap. It launches a Shiny app where you walk
through the time series group by group, zoom, and flag anomalies –
without writing any filtering code.

All columns that are not `x`, `y`, `series`, or excluded automatically
become dropdown filters. Requires `shiny` and `plotly`. Group row
indices are prepared once, and plots are built directly with Plotly for
fast navigation.

``` r
df <- expand.grid(
  year    = 2010:2020,
  country = c("DK", "SE", "NO", "FI")
)
df$gdp <- rnorm(nrow(df), mean = 300, sd = 30)

screen_timeseries(df, x = year, y = gdp)

# Multiple lines per group with series:
ggplot2::economics_long |>
  mutate(group = "Economics") |>
  screen_timeseries(date, value, series = variable, .exclude = value01)
```

**Keyboard shortcuts**

| Key         | Action                            |
|-------------|-----------------------------------|
| `<-` / `->` | Navigate to previous / next group |
| `Space`     | Flag the current group            |
| `R`         | Reset zoom                        |
| `Q`         | Quit and return flagged groups    |

The `.y_min` and `.y_max` arguments fix the Y-axis bounds globally
across all groups. The `.title` argument sets a title shown in the app
header and in downloaded figures:

``` r
screen_timeseries(df, year, gdp,
                  .y_min = 0, .y_max = 500,
                  .title = "GDP by country")
```

Press **Q**, click **Finish**, or close the browser session to end
screening. The function returns flagged group keys invisibly and also
prints pasteable R code such as
`flagged <- tibble::tibble(country = c("DK", "NO"))`. This preserves the
result even if you did not assign the call to an object. Use
`.print = FALSE` to suppress the console code when desired. Reloading
the browser also ends its session, so restart
[`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
to begin again.

**Choose diagnostics inside the app**

All diagnostic tools start switched off. Select any combination of
**Statistics**, **Seasonality**, **Outliers**, **Stationarity**,
**Autocorrelation**, and **Structural breaks** using the checkboxes.
Only selected tools run; results are cached within the session. Your
choices remain active as you navigate through groups. With multiple
lines, use **Series to diagnose** to choose one line for analysis.

Results share a compact panel inside the main graph card. Switch between
enabled analyses using the tabs; each shows its conclusion alongside the
figures or a small diagnostic plot. **Overview** gathers the main
findings; click a finding to open that analysis. Data quality, full
outlier tables and method notes open in dialogs. On desktop screens, the
graph adjusts its height to keep the active results in view. Keys **1**
to **6** toggle tools in sidebar order; arrow keys on a focused result
tab switch tabs.

- **Seasonality** adds a dashed trend-plus-season line to the main plot
  and a seasonal profile alongside it. The profile is in the original
  units.
- **Outliers** marks unusual residual observations on the main plot.
- **Autocorrelation** displays ACF and PACF plots below the main plot.
- **Stationarity** shows KPSS and Phillips–Perron results, including
  their different null hypotheses and interpretations.
- **Structural breaks** marks candidate dates on the main plot and
  displays confidence limits. Choose a level or trend model in the app.

The **Seasonal period** control sets observations per seasonal cycle,
such as 12 for monthly observations with annual seasonality. Leave it
blank to infer annual seasonality for calendar months/quarters; other
indices default to 1 (no seasonality). `.period = 12` can pre-fill this
control, but does not enable any tool. Gaps, duplicate dates and
missing/non-finite values are reported, and prevent time-dependent
analysis without silently modifying data.

Descriptive statistics, decomposition, outlier screening and
correlations use base R. Stationarity tests additionally need `feasts`
and `urca`; structural breaks need `strucchange`. The app explains
unavailable analyses. Break searches are limited to 30–2000
observations, use BIC to choose up to three breaks, and require segments
of at least 15% (and at least 10 observations). Outlier and break
markers are candidates for review, not corrections.

The same diagnostic engine is available outside Shiny. Group explicitly
by the columns identifying **one** time series:

``` r
df |>
  group_by(country) |>
  diagnose_timeseries(year, gdp, .features = c("summary", "stationarity"))
```

This returns one row per group with scalar statistics and list columns
for test results, outliers, break dates, correlations, decomposition and
notes. See
[`?diagnose_timeseries`](https://dataniel.github.io/daos/reference/diagnose_timeseries.md)
for sample-size requirements and method details.
