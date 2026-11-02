# Getting started with daos

The **daos** package is a collection of utility functions built for
day-to-day statistical work. This vignette walks through every function
with short, self-contained examples.

Several bodies of work that started here have since grown into packages
of their own, and are not covered below: taskr for task management,
statbank for the Greenland and Faroese statbanks (both private for now),
[cvrr](https://github.com/dataniel/cvrr) for published Danish annual
reports, [taxmill](https://github.com/dataniel/taxmill) for milling PDF
financial statements into data,
[pathr](https://github.com/dataniel/pathr) for the file browser and the
RStudio addins that take the friction out of Windows paths, and
[pnr](https://github.com/dataniel/pnr) for CPR numbers. None of them
depends on daos, or daos on them.

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
#> [1] "20261102"
nowf("%Y-%m-%d %H:%M")  # custom format
#> [1] "2026-11-02 00:09"
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

## Files: the lazer package

The readers and writers have moved to their own package,
[lazer](https://github.com/dataniel/lazer): `read_files()`,
`read_workbook()`, `inspect_excel()`, `write_excel()`, `read_access()`
and `read_sut()`, `write_sut()` and `convert_sut()` for supply and use
table files (SUT, the TA files). Use
[`library(lazer)`](https://rdrr.io/r/base/library.html), and see
`vignette("lazer", package = "lazer")`.

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

------------------------------------------------------------------------

## Data inspection

### `view_types()`: compare column types across data frames

[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
is [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) across
several data frames at once: one row per column, with the type in each
dataset. Useful before a join, or before binding with
`read_files(out = "bind")`.

The `status` column says whether the frames would bind: `ok`,
`coercible` (types differ but combine, like `int` + `dbl` or an all-`NA`
column with anything), `missing` (absent somewhere, which
[`bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
fills with `NA`), or `conflict` (the bind fails).

``` r
df_a <- data.frame(x = 1L,  y = "a", z = NA)
df_b <- data.frame(x = 1.0, y = 2,   z = "b", w = 1)

view_types(df_a, df_b)
#> # A tibble: 4 × 4
#>   column status    df_a  df_b 
#>   <chr>  <chr>     <chr> <chr>
#> 1 x      coercible int   dbl  
#> 2 y      conflict  chr   dbl  
#> 3 z      coercible lgl   chr  
#> 4 w      missing   NA    dbl
```

``` r
# Only the columns that would break a bind:
view_types(df_a, df_b, diff = TRUE)
#> # A tibble: 1 × 4
#>   column status   df_a  df_b 
#>   <chr>  <chr>    <chr> <chr>
#> 1 y      conflict chr   dbl
```

The output of `read_files()` can be passed directly, since a named list
of data frames is unpacked:

``` r
lazer::read_files("data/dat{2020:2023}.parquet", names = 2020:2023) |>
  view_types(diff = TRUE)
```

The `focus` argument checks that specific columns have an expected type
and returns only the datasets where they do not:

``` r
view_types(df_a, df_b, focus = c(x = "int", y = "chr"))
#> # A tibble: 2 × 3
#>   column status    df_b 
#>   <chr>  <chr>     <chr>
#> 1 x      coercible dbl  
#> 2 y      conflict  dbl
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

Both functions inspect data before you settle on a rule. Turning a rule
into a checkpoint is the job of the expectr package, below.

------------------------------------------------------------------------

## Data validation: the expectr package

The validation checkpoints, `expect_empty()`, `expect_none()` and
`tally_violations()`, have moved to their own package,
[expectr](https://github.com/dataniel/expectr). They share an engine and
a contract the rest of daos does not: each states an expectation about
data as “the set of violations must be empty”. The checks on the
structure of register data, unique keys, balanced panels and overlapping
spells, are in [lustrum](https://github.com/dataniel/lustrum), together
with `spells_to_panel()` and `add_spell_status()`.

Load expectr to use them:

``` r
library(expectr)

lazer::read_files("data/dat{2020:2023}.parquet", names = 2020:2023) |>
  view_types(diff = TRUE) |>
  expect_empty(warn_msg = "The files do not bind")
```

See `vignette("expectr", package = "expectr")`.

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

`spells_to_panel()` and `add_spell_status()`, which turn spells into a
panel with primo and ultimo status, have moved to
[lustrum](https://github.com/dataniel/lustrum).

------------------------------------------------------------------------

## Domain-specific

### `clean_cvr()`: standardise CVR numbers

CVR numbers rarely arrive in one consistent shape: `12 34 56 78` or
`DK12345678`. Before a join, both sides need the same form, and that is
all
[`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md)
does. It takes a vector and returns a vector, so the natural place for
it is inside a
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html):

``` r
clean_cvr(c("DK12345678", "12 34 56 78", "12345678"))
#> [1] "12345678" "12345678" "12345678"
```

It never adds a digit: a seven-digit CVR cannot be told apart from a
typo, and padding it would let a malformed number slip past a later
`cvr %like% "^\\d{8}$"` checkpoint. It does not validate either.
Malformed values come back cleaned but still visibly malformed.

CPR numbers are handled by the pnr package, where `clean_cpr()` does pad
nine-digit values: birth days 01 to 09 make that padding unambiguous.

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
