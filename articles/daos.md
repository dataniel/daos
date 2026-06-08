# Getting started with daos

The **daos** package is a collection of utility functions built for
day-to-day statistical work. This vignette walks through every function
with short, self-contained examples.

------------------------------------------------------------------------

## Convenience shorthands

### `f()` – string interpolation

[`f()`](https://dataniel.github.io/daos/reference/f.md) is a short alias
for [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html),
inspired by Python’s f-string syntax. The name is deliberately brief –
not self-explanatory, but fast to type and visually unobtrusive in a
pipeline.

``` r

year <- 2026
f("Report for {year}")
#> Report for 2026
f("1 + 1 = {1 + 1}")
#> 1 + 1 = 2
```

### `nowf()` – formatted timestamp

[`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) combines
[`format()`](https://rdrr.io/r/base/format.html) and
[`Sys.time()`](https://rdrr.io/r/base/Sys.time.html) into a single call.
The motivation is simple: when timestamping an export, you want to write
[`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) inline
without stopping to think about the `format(Sys.time(), ...)` signature.

``` r

nowf()                  # default: YYYYMMDD
#> [1] "20260608"
nowf("%Y-%m-%d %H:%M")  # custom format
#> [1] "2026-06-08 21:30"
```

A common pattern – timestamping an export file:

``` r

iris |>
  writexl::write_xlsx(f("iris_{nowf('%Y%B')}.xlsx"))
```

### `quiet()` – suppress messages and warnings

A shorthand for `suppressMessages(suppressWarnings(...))`. Useful when
you grow tired of tidyverse startup banners, or when running R scripts
as CLI tools (e.g. with `rapp`) or in presentation tools like
`presenterm` where console output must be clean.

``` r

quiet(message("this will not appear"))
quiet(warning("neither will this"))
```

### `is_blank()` – comprehensive blank test

[`is.na()`](https://rdrr.io/r/base/NA.html) only catches `NA`.
[`rlang::is_empty()`](https://rlang.r-lib.org/reference/is_empty.html)
only catches `NULL` and zero-length vectors.
[`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)
covers all three plus empty strings – useful when validating input that
may arrive in any of these forms.

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

### `%??%` – null-coalescing with blank detection

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

### `%like%` – regex matching with NA preservation

`%like%` is intended as a more readable replacement for `str_detect()`.
The infix form reads naturally in a
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) call,
and unlike [`grepl()`](https://rdrr.io/r/base/grep.html), `NA` values
are preserved as `NA` rather than silently coerced to `FALSE` – which
matters when filtering on optional fields.

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

### `read_files()` – validate, read, and collect

Reading a set of files in base R or tidyverse requires a pipeline of
[`list.files()`](https://rdrr.io/r/base/list.files.html),
[`lapply()`](https://rdrr.io/r/base/lapply.html) or
[`purrr::map()`](https://purrr.tidyverse.org/reference/map.html), and
manual naming. As a statistician you want one function for one thing.
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
handles path expansion, existence checks, format detection, naming, and
collection in a single call.

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
works best when data production is consistent – same formats, same
column names, same types across files. If
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
handles a set of files without warnings, the workflow is in order. When
it warns about type mismatches, that is a signal that something has
changed upstream.

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
aborts if any name already exists – set `.overwrite = TRUE` to allow
overwriting.

``` r

read_files("data/dat{0:9}.parquet", names = paste0("dat", 0:9), out = "unpack")
```

### `summon()` – retrieve objects by name pattern

A regex-based alternative to [`ls()`](https://rdrr.io/r/base/ls.html) +
[`mget()`](https://rdrr.io/r/base/get.html). The base R equivalent is
functional but somewhat clunky:

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

### `read_access()` – read from a Microsoft Access database

Connects to an `.mdb` or `.accdb` file via ODBC, executes a SQL query,
and returns the result as a tibble. Requires the `DBI` and `odbc`
packages and a Microsoft Access ODBC driver.

The `verbosity` argument controls output:

- `"compact"` (default) – one line per file, best when looping
- `"full"` – header, spinners, and summary; best for single files
- `"quiet"` – no output

``` r

# Full output for interactive use:
df <- read_access("data/sales.mdb", "SELECT * FROM Customers",
                  verbosity = "full")

# Loop over many databases quietly:
files <- fs::dir_ls("data", glob = "*.mdb")
results <- purrr::map(files, \(f) read_access(f, "SELECT * FROM Sales"))
```

### `read_xbrl()` – parse an XBRL file

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

### `accounts_pdf_to_txt()` – convert PDF accounts to text

Reads all PDF files in a directory, extracts their text, and writes one
`.txt` file per PDF. Intended as the first step in a manual review
workflow for financial statements. Requires `pdftools`.

``` r

accounts_pdf_to_txt(
  pdf_dir = "data/pdf",
  txt_dir = "data/txt"
)
```

The output directory is created automatically if it does not exist. File
names (typically CVR numbers) are preserved.

### `accounts_txt_to_xlsx()` – parse accounts text files to Excel

Parses manually formatted text files and exports the result as an Excel
file. Requires `writexl`.

**Text file format**

Each line is either a *category line* or a *data line*:

- **Category line:** a single string with no field delimiter. Sets the
  `note` value for all subsequent data lines.
- **Data line:** three fields separated by `min_spaces` or more
  consecutive spaces: (1) element name, (2) amount for `year`,
  3.  amount for `year - 1`.

Amounts must be whole kroner; periods used as thousands separators are
stripped automatically. If no previous-year amount exists, the third
field may be empty – it becomes `NA`.

Appending `statnatio` to a category line negates all amounts in that
category, useful when costs appear with a positive sign in notes. The
suffix is stripped from the final output.

File names are used as identifiers in the `cvr` column. A trailing
`_spec` suffix is stripped automatically.

``` r

df <- accounts_txt_to_xlsx(
  txt_dir  = "data/txt",
  out_file = "data/output.xlsx",
  year     = 2024
)
```

Three validation checks run automatically and abort on failure:

1.  Comma in value columns – indicates wrong decimal separator
2.  `NA` in `note` or `elementid` – indicates a missing category line
3.  `NA` in current-year values – indicates a parsing failure

### `write_pretty_xlsx()` – write to Excel with sensible defaults

[`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
is fast but bare: no formatting, no frozen header, no number formatting.
`openxlsx2` can do all of that, but its API requires you to build a
workbook object, add worksheets, apply styles, and save – many lines for
what should be a one-liner.
[`write_pretty_xlsx()`](https://dataniel.github.io/daos/reference/write_pretty_xlsx.md)
is the middle ground: a single call with defaults that cover the most
common needs.

- Numeric columns with at least one value ≥ 1,000 are formatted with a
  thousand separator and no displayed decimals (`#,##0`); the underlying
  values are preserved.
- `NA` values appear as blank cells.
- The header row is bold.
- The first row is frozen (can be turned off with
  `freeze_header = FALSE`).

**Writing a new file**

Pass a data frame or a named list of data frames to `data`. Requires
`overwrite = TRUE` if the file already exists.

``` r

# Single data frame -- sheet name defaults to "Sheet1"
write_pretty_xlsx(mtcars, "output.xlsx")

# Named list -- each element becomes a sheet
write_pretty_xlsx(
  list(Cars = mtcars, Iris = iris),
  "output.xlsx"
)
```

**Sheet naming**

Sheet names come from the list names. Unnamed elements get default names
(`"Sheet1"`, `"Sheet2"`, …). Mixed naming is also fine:

``` r

# "Hoved" is explicit; second sheet becomes "Sheet2"
write_pretty_xlsx(list(Hoved = mtcars, iris), "output.xlsx")
```

**Appending sheets to an existing file**

Use `append` to add sheets without touching the existing content. The
file must already exist, and `overwrite = TRUE` is required if a sheet
of the same name is already present.

``` r

# Add one sheet
write_pretty_xlsx(append = list(Bilag = airquality), path = "output.xlsx")

# Create and append in a single call
write_pretty_xlsx(
  list(Hoved = mtcars),
  "output.xlsx",
  append = list(Bilag = iris)
)
```

**Other options**

``` r

# Insert as an Excel table (filter arrows, banded rows)
write_pretty_xlsx(mtcars, "output.xlsx", as_table = TRUE)

# Exclude columns from the #,##0 format
write_pretty_xlsx(mtcars, "output.xlsx", skip_fmt = "hp")
```

### `read_ta()` / `write_ta()` – read and write Greenlandic TA files

``` r

df <- read_ta("ta.file")
write_ta(df, "ta.file")
```

------------------------------------------------------------------------

## Data inspection

### `view_types()` – compare column types across data frames

Think of
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
as [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) across
multiple data frames at once – it shows the type of each column for
every dataset supplied. Invaluable before joins or before binding with
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

### `size_env()` – object sizes in an environment

A simple answer to “what is taking up space?” – lists all objects in an
environment sorted by size.

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

### `expect_empty()` – assert a data frame is empty

Often you want to assert that a filtering condition finds nothing – and
if it does find something, you want to know immediately with a clear
message. Writing a custom `if (nrow(x) > 0) cli::cli_abort(...)` every
time is repetitive.
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
does this in one step, fits into a pipeline, and optionally writes to a
log file.

By filtering for impossibilities and piping through
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md),
you have the offending rows at hand the moment something goes wrong.

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

# Warning -- rows found:
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

The `log` argument writes a timestamped entry to a file. When you
eventually open RStudio to investigate, the errors are already
collected:

``` r

log_path <- f("log/{nowf()}/checks.log")
checker  <- purrr::partial(expect_empty, log = log_path)

dplyr::starwars |>
  filter(name == "Harry Potter") |>
  checker(success_msg = "No fictional characters")

dplyr::starwars |>
  filter(height > 250) |>
  checker(warn_msg = "Unusually tall characters")
```

### `flag_duplicates()` – detect and label duplicate rows

Base R’s [`duplicated()`](https://rdrr.io/r/base/duplicated.html) only
marks the second occurrence of a duplicate.
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
marks all copies and assigns them a shared group ID – making it easy to
inspect all instances at once. The ID can also serve as an implicit
record linkage key: if multiple respondents have reported the same
information but background data is missing for one person, the shared
`dupid` reveals the connection.

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

### `split_by()` – split a data frame into a named list

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

### `find_signs()` – reconcile accounting line items

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

### `cpr_info()` – extract birth date, age, sex, and validity

[`cpr_info()`](https://dataniel.github.io/daos/reference/cpr_info.md)
appends derived columns to a data frame using official CPR Register
century-detection rules. Dashes and spaces are stripped automatically;
nine-digit numbers are zero-padded.

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

### `track_last_df()` – auto-save the last printed data frame

Automatically captures any data frame returned to the console as
`.last.df` in the global environment. Handy when you forget to assign an
intermediate result.

``` r

track_last_df()          # enable

dplyr::starwars |> head(3)
.last.df                 # the three-row data frame above

track_last_df(FALSE)     # disable
```

### `screen_timeseries()` – interactive time-series screening

Many people find it hard to get close enough to data when working in a
console – Excel’s immediate, visual feedback is difficult to replicate.
[`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
is an attempt to bridge that gap: it launches a Shiny app where you
navigate time series group by group, zoom in, and flag anomalies –
without writing any filtering code.

All columns that are not `x`, `y`, `series`, or excluded automatically
become dropdown filters. Requires `shiny` and `highcharter`.

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

------------------------------------------------------------------------

## RStudio addins

The following addins are available via the *Addins* menu or the command
palette (`Ctrl+Shift+P`). Keyboard shortcuts can be bound under *Tools
-\> Modify Keyboard Shortcuts*.

### Fix Windows paths

Replaces backslashes with forward slashes in Windows-style paths
(`C:\...` or `\\server\...`). Only path-like backslashes are converted –
`\(x)` lambda syntax and escape sequences like `\n` are left untouched.

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
line-delimited list copied from Excel or a mail.
