# Getting started with daos

The **daos** package is a collection of utility functions built for
day-to-day statistical work. This vignette walks through every function
with short, self-contained examples.

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
#> [1] "20260615"
nowf("%Y-%m-%d %H:%M")  # custom format
#> [1] "2026-06-15 00:44"
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
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
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

### `read_xbrl()`: parse an XBRL file

Parses an XBRL XML document and returns a tidy tibble with one row per
fact, joined to context (dates) and unit information. Requires `xml2`.

``` r

df <- read_xbrl("report.xml")
```

The returned tibble has columns: `elementid`, `contextid`, `fact`,
`unitid`, `decimals`, `startdate`, `enddate`, `instant`,
`explicit_member`, `unit`.

For non-UTF-8 files, pass `encoding`:

``` r

df <- read_xbrl("report.xml", encoding = "latin1")
```

The full path from downloaded annual reports to parsed facts, including
sign reconciliation with
[`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md),
is shown in
[`vignette("cvr")`](https://dataniel.github.io/daos/articles/cvr.md).

### Accounts and CVR workflows

Two larger workflows have their own articles instead of a walkthrough
here:

- [`vignette("cvr")`](https://dataniel.github.io/daos/articles/cvr.md)
  covers responsible use of the `cvr_*` pipeline for fetching published
  annual reports from Erhvervsstyrelsens distribution service:
  [`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md),
  [`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md),
  [`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md),
  [`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md).
- [`vignette("accounts")`](https://dataniel.github.io/daos/articles/accounts.md)
  covers the manual accounts workflow behind
  [`accounts_pdf_to_txt()`](https://dataniel.github.io/daos/reference/accounts_pdf_to_txt.md)
  and
  [`accounts_txt_to_xlsx()`](https://dataniel.github.io/daos/reference/accounts_txt_to_xlsx.md):
  from PDF reports through hand-formatted text files to one validated,
  tidy Excel file.

### `write_excel()` / `append_excel()`: write presentable Excel files

These two functions exist because a plain data export is hard to read
for the people the file is meant for. The complaint from a colleague who
works with macroeconomic statistics was concrete: no frozen header, no
thousand separators, no rounding.
[`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
is fast but writes exactly such unformatted files, and `openxlsx2` can
do all the styling but wants a workbook object, worksheets, styles, and
a save call.
[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
sits in between: one call, with defaults that make the file presentable.

- Numeric columns with at least one value ≥ 1,000 are formatted with a
  thousand separator and no displayed decimals (`#,##0`); the underlying
  values are preserved.
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

Pass a data frame or a named list of data frames. Requires
`overwrite = TRUE` if the file already exists.

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

[`append_excel()`](https://dataniel.github.io/daos/reference/append_excel.md)
adds sheets without touching the existing content. The file must already
exist, and `overwrite = TRUE` is required if a sheet of the same name is
already present.

``` r

write_excel(list(Hoved = mtcars), "output.xlsx")
append_excel(list(Bilag = iris), "output.xlsx")
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

------------------------------------------------------------------------

## Data inspection

### `view_types()`: compare column types across data frames

[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
is [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) across
several data frames at once: one row per column, with the type in each
dataset. Useful before a join, or before binding with
`read_files(out = "bind")`.

``` r

df_a <- data.frame(x = 1L,  y = "a", z = TRUE)
df_b <- data.frame(x = 1.0, y = "b", z = 1L)

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

The `focus` argument checks that a specific column has an expected type
and returns only the datasets where it does not:

``` r

view_types(df_a, df_b, focus = c(x = "int"))
#> # A tibble: 1 × 2
#>   column df_b 
#>   <chr>  <chr>
#> 1 x      dbl
```

------------------------------------------------------------------------

## Data validation

The checkpoint pattern behind these two functions has its own article,
[`vignette("validation")`](https://dataniel.github.io/daos/articles/validation.md),
which shows how to build lightweight validation into pipelines with
them.

### `expect_empty()`: assert a data frame is empty

Often you want to assert that a filter finds nothing, and to hear about
it right away when it does. Writing a custom
`if (nrow(x) > 0) cli::cli_abort(...)` every time gets repetitive.
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
does it in one step, fits into a pipeline, and can write to a log file.

Filter for the rows that should not exist, pipe them in, and the
offending rows are at hand the moment something goes wrong.

``` r

# Success:
dplyr::starwars |>
  filter(name == "Harry Potter") |>
  expect_empty(
    success_msg = "No Harry Potter rows in starwars",
    warn_msg    = "Unexpected fictional character found"
  )
#> ✔ No Harry Potter rows in starwars
```

``` r

# Warning: rows found
dplyr::starwars |>
  filter(mass > 1000) |>
  expect_empty(warn_msg = "Unrealistic mass values")
#> Warning: Unrealistic mass values
```

``` r

# Hard abort:
dplyr::starwars |>
  filter(mass > 1000) |>
  expect_empty(abort_msg = "Unrealistic mass values")
```

The `log` argument writes a timestamped entry to a file, so when a
scheduled run misbehaves, the errors are already collected by the time
you sit down to investigate:

``` r

log_path <- f("log/{nowf()}/checks.log")
checker  <- \(data, ...) expect_empty(data, ..., log = log_path)

dplyr::starwars |>
  filter(name == "Harry Potter") |>
  checker(success_msg = "No fictional characters")

dplyr::starwars |>
  filter(height > 250) |>
  checker(warn_msg = "Unusually tall characters")
```

### `flag_duplicates()`: detect and label duplicate rows

Base R’s [`duplicated()`](https://rdrr.io/r/base/duplicated.html) only
marks the second occurrence of a duplicate.
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
marks all copies and gives them a shared group ID, so the whole group
can be inspected together. The ID can also serve as an implicit record
linkage key: if several respondents have reported the same information
but background data is missing for one of them, the shared `dupid`
reveals the connection.

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

### `drop_all_na()`: drop empty rows and/or columns

After a join or import you often end up with rows or columns that are
entirely `NA`.
[`drop_all_na()`](https://dataniel.github.io/daos/reference/drop_all_na.md)
removes them. Unlike
[`tidyr::drop_na()`](https://tidyr.tidyverse.org/reference/drop_na.html)
(which drops a row on the *first* `NA`), it only drops a row or column
where *every* value is `NA`. It is equivalent to
`janitor::remove_empty()` with `cutoff = 1`, reimplemented here to keep
the dependency footprint small:

``` r

df <- tibble::tibble(
  a = c(1, NA, 3),
  b = c(NA, NA, NA),
  c = c("x", NA, "z")
)

drop_all_na(df)                  # column b and the all-NA row
#> # A tibble: 2 × 2
#>       a c    
#>   <dbl> <chr>
#> 1     1 x    
#> 2     3 z
drop_all_na(df, which = "rows")  # only the all-NA row
#> # A tibble: 2 × 3
#>       a b     c    
#>   <dbl> <lgl> <chr>
#> 1     1 NA    x    
#> 2     3 NA    z
drop_all_na(df, which = "cols")  # only column b
#> # A tibble: 3 × 2
#>       a c    
#>   <dbl> <chr>
#> 1     1 x    
#> 2    NA NA   
#> 3     3 z
```

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

### `find_signs()`: reconcile accounting line items

[`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md)
finds the signs (`+1`, `-1`, or `0`) that make a set of values sum to a
given total. Useful when importing accounting data where the sign
conventions are unknown. It uses a *meet-in-the-middle* algorithm, so it
stays fast even with many line items.

``` r

items <- data.frame(
  label = c("revenue", "costs", "tax", "total"),
  value = c(1000, 400, 100, 500)
)

find_signs(items, label, value, total_label = "total")
#> # A tibble: 0 × 0
```

Pin known signs and allow items to be excluded with `max_zeros`:

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
job (below), or a checkpoint from
[`vignette("validation")`](https://dataniel.github.io/daos/articles/validation.md).

### `dbdot()`: format DB07 industry codes with dots

DB07 industry codes appear both as `011100` and `01.11.00` depending on
the source.
[`dbdot()`](https://dataniel.github.io/daos/reference/dbdot.md)
normalises to the dotted form. Existing dots are stripped first, so
mixed input comes out uniform and running it twice changes nothing. Any
aggregation level works:

``` r

dbdot(c("011100", "01.1100", "0111", "011"))
#> [1] "01.11.00" "01.11.00" "01.11"    "01.1"
```

The bare-digit inverse is just `gsub("[.]", "", x)`. Like the `clean_*`
functions,
[`dbdot()`](https://dataniel.github.io/daos/reference/dbdot.md) never
invents digits: a code that lost its leading zero in Excel is ambiguous
(`111` could be group `11.1` or class `01.11`), so keep industry codes
as character columns.

### `add_cpr_info()`: add birth date, age, sex, and validity

[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
appends derived columns to a data frame using official CPR Register
century-detection rules. Dashes and spaces are stripped automatically,
and nine-digit numbers are zero-padded.

A word on validity: `valid` means ten digits encoding a real calendar
date, and nothing more. The modulus-11 check is not part of it, because
the CPR office has assigned numbers without mod-11 control since 2007
and states that they are fully valid. The check is still available as
the separate `mod11` column, where it works as a data quality signal.
The implementation is plain vectorised arithmetic (a digit matrix,
mod-11 as a matrix product, dates built as day counts instead of parsed
strings), so a few million rows take seconds.

``` r

df <- data.frame(
  pnr = c("1111111118", "111111-1118", "111111118"),
  stringsAsFactors = FALSE
)

add_cpr_info(df, pnr)
#>          pnr       bday age sex mod11 valid
#> 1 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 2 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 3 0111111118 1911-11-01 114   0 FALSE  TRUE
```

Choose a subset of columns and optionally rename them:

``` r

add_cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#>          pnr birth_date years_old
#> 1 1111111118 1911-11-11       114
#> 2 1111111118 1911-11-11       114
#> 3 0111111118 1911-11-01       114
```

A custom reference date shifts the age calculation:

``` r

add_cpr_info(df, pnr, add = "age", ref_date = "2000-01-01")
#>          pnr age
#> 1 1111111118  88
#> 2 1111111118  88
#> 3 0111111118  88
```

### `statbank_*`: the Greenland Statbank

The `statbank_*` family is a small client for the Greenland Statbank
(bank.stat.gl). Search the table list, look up a table’s variables, and
download the data as a tidy tibble:

``` r

statbank_search("befolkning")

meta <- statbank_meta("BE/BE01/BEXSAT1.PX")
meta$variables

df <- statbank_get(
  "BE/BE01/BEXSAT1.PX",
  tid = c(2023, 2024, 2025),
  art = "Antal"
)
```

Selections in
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)
are matched against both variable codes and their Danish display texts,
and against both value codes and value texts, so you can write
`art = "Antal"` without knowing that the internal code is `Number`.
Matching also folds Danish letters (`foedested` matches `fødested`).
Variables you do not mention default to all values.

The result can be shaped with three dot-prefixed options:
`.col_names = "code"` names the columns by variable codes instead of
display texts, `.values = "code"` fills the cells with value codes (so a
sex variable coded 0/1 comes back as 0/1), and `.type_convert = FALSE`
turns off the automatic
[`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html)
that otherwise makes e.g. year columns numeric.

The first call to
[`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md)
or
[`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md)
walks the statbank’s table tree (one small request per folder) and
caches the list for the rest of the session.

The same functions also reach the Faroese statbank (Hagstova Føroya) via
`bank = "fo"`. Each bank has its own languages, so `lang` defaults to
the bank’s own default (Danish for Greenland, Faroese for the Faroe
Islands) rather than a fixed value:

``` r

statbank_search("wages", bank = "fo")
df <- statbank_get("IP/IP02/pris_alt.px", bank = "fo")
```

[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
wraps the family in a Shiny app: find a table by browsing the subject
tree (a three-column, yazi-style browser with keyboard navigation) or
searching, pick values in popup checklists, preview the data and a plot,
and copy the
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)
call that reproduces the selection. The bank switcher sits one level
above the subject root, so the same app covers both Greenland (the
default) and the Faroe Islands. The app is meant as the bridge from
clicking to scripting; the code tab always shows the query you built.
Data can be downloaded as formatted Excel, and pressing Q closes the app
and returns the last fetched dataset to R. Requires `shiny` and
`ggplot2`.

``` r

statbank_app()
```

The thinking behind the app – keyboard-driven, guided navigation of a
statbank, and where that idea is heading – is its own article,
[`vignette("statbank")`](https://dataniel.github.io/daos/articles/statbank.md).

------------------------------------------------------------------------

## Interactive tools

### `screen_timeseries()`: interactive time-series screening

It is hard to get as close to data in a console as in Excel, where the
feedback is immediate and visual.
[`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
is an attempt to bridge that gap. It launches a Shiny app where you walk
through the time series group by group, zoom, and flag anomalies –
without writing any filtering code.

All columns that are not `x`, `y`, `series`, or excluded automatically
become dropdown filters. Requires `shiny`, `ggplot2`, and `plotly`.

``` r

df <- expand.grid(
  year    = 2010:2020,
  country = c("DK", "SE", "NO", "FI")
)
df$gdp <- rnorm(nrow(df), mean = 300, sd = 30)

screen_timeseries(df, x = year, y = gdp)

# Multiple lines per group with series:
ggplot2::economics_long |>
  screen_timeseries(date, value, series = variable)
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

### `task_*`: a shared task manager

The `task_*` family is a small taskwarrior-style task manager backed by
a shared SQLite file. SQLite is free (public domain, bundled by
`RSQLite`), runs in WAL mode, and needs no server – so a `.sqlite` file
on a network drive is enough for a team to work from, several people at
once.

``` r

task_db("tasks.sqlite")                       # create/open the database

task_add("tasks.sqlite", "Write the report",
         project = "Q3", assignee = "Anna", tags = c("writing", "urgent"),
         priority = "H", due = "2026-07-01")

task_list("tasks.sqlite")                     # tibble sorted by urgency
task_list("tasks.sqlite", assignee = "Anna")  # filter by person
task_done("tasks.sqlite", id = 1)             # complete a task
```

Tasks carry a project, an assignee (person), tags, priority, due date,
recurrence, dependencies and annotations;
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
adds a `blocked` flag and a simplified urgency score. Every function
opens a short-lived connection, works in one transaction, and closes, so
concurrent users are handled safely. The database is just a shared file
– point at a path that does not exist yet and a fresh one is created.

[`task_app()`](https://dataniel.github.io/daos/reference/task_app.md) is
a Shiny front-end over the same database: add and edit tasks, filter by
person/project/tag/status, see project and people overviews, and watch
the list update as others change it (it re-reads on a timer). Requires
`shiny`, `DBI`, and `RSQLite`.

``` r

task_app("tasks.sqlite")
```

Because every `task_*` function is a plain call against the shared file,
task updates can be embedded in production scripts – so the same
database the team browses also records how production is going. That way
of working is covered in
[`vignette("tasks")`](https://dataniel.github.io/daos/articles/tasks.md).

### `browse_files()`: grab filesystem paths without typing them

Typing or hand-fixing long Windows paths is tedious.
[`browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md)
launches a small Shiny app that walks the filesystem in the same
three-column, yazi-style browser as
[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
– parent directory, current directory, and a live preview – navigated
with `h`/`j`/`k`/`l` or the arrow keys. The point is to grab paths: mark
one or more files or folders with `Space`, then take them into R.

``` r

p <- browse_files()           # navigate, mark, press Q
```

Pressing `Q` returns the marked paths – a single string for one, a
`c("a", "b")` vector for several – with forward slashes, so the result
drops straight into a script. `y` copies the same R expression to the
clipboard, and `o` opens the item under the cursor in the system file
explorer (reusing
[`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)).
Requires `shiny`.

[`browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md),
the explorer addins, and
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
together make up a way of handling many sources without a file explorer
open alongside RStudio;
[`vignette("paths")`](https://dataniel.github.io/daos/articles/paths.md)
walks through it.

------------------------------------------------------------------------

## RStudio addins

The following addins are available via the *Addins* menu or the command
palette (`Ctrl+Shift+P`). Keyboard shortcuts can be bound under *Tools
-\> Modify Keyboard Shortcuts*.

### Fix Windows paths

Replaces backslashes with forward slashes in Windows-style paths
(`C:\...` or `\\server\...`). Only path-like backslashes are converted;
`\(x)` lambda syntax and escape sequences like `\n` are left alone.

- **Text selected:** operates on the selection only
- **Nothing selected:** operates on the entire active file and restores
  the cursor position

### Text to vector

Converts selected lines (one item per line) to an R character vector
expression. Empty lines are ignored.

Selecting:

    12345678
    87654321
    11223344

produces:

``` r

c(
  "12345678",
  "87654321",
  "11223344"
)
```

Useful for quickly wrapping CVR numbers, variable names, or any
line-delimited list copied from Excel or an email.

### Open in file explorer

Opens a location in the system file explorer.

- **A path selected:** opens it directly if it is a folder, or reveals
  the file inside its containing folder if it is a file
- **An object or call selected:** the selection is evaluated as R code,
  so `my_path` or `file.path(dir, "data.csv")` work too
- **Just the cursor on a token (no selection):** the path-like word
  under the cursor is used, so you can place the cursor on a path or an
  object holding one without selecting it (paths with spaces still need
  to be selected)
- **Cursor on whitespace / nothing selected:** opens the current working
  directory ([`getwd()`](https://rdrr.io/r/base/getwd.html))

A literal path that exists on disk is used as-is; anything else is
evaluated, making it easy to jump from a path stored in a variable
straight to its location on disk.
