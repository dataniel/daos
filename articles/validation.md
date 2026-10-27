# Lightweight data validation with checkpoints

Statistical production code lives or dies on small assumptions: no
duplicate units, no negative amounts, no person with two addresses at
once. A full validation framework such as pointblank or validate is
often more ceremony than the job needs. The alternative is a
*checkpoint*: one line that states the assumption and stops the pipeline
(or shouts) the moment it breaks.

The pattern is always the same:

> **Express the rule as “the set of violations must be empty”, build
> that set with ordinary dplyr, and pass it to a checkpoint.**

The rule language is just dplyr, so there is nothing new to learn. The
package only adds checkpoints for the rules that are awkward to write as
a [`filter()`](https://dplyr.tidyverse.org/reference/filter.html):
unique keys, balanced panels and overlapping spells. All of them are
common in register data.

| Function                                                                                | The rule                                         | Returns       |
|-----------------------------------------------------------------------------------------|--------------------------------------------------|---------------|
| [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)           | the data frame you pass has no rows              | the input     |
| [`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)             | no row matches a condition                       | the full data |
| [`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md)         | the key columns identify each row                | the full data |
| [`expect_balanced()`](https://dataniel.github.io/daos/reference/expect_balanced.md)     | every unit is observed in every period           | the full data |
| [`expect_no_overlap()`](https://dataniel.github.io/daos/reference/expect_no_overlap.md) | a unit’s spells do not overlap                   | the full data |
| [`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md)   | counts violations for many rules, judges nothing | a tally       |

## The checkpoint: `expect_empty()`

[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
succeeds when the data frame it receives has zero rows. Filter for the
rows that *should not exist*, and pipe them in:

``` r
starwars |>
  filter(height < 0) |>
  expect_empty(warn_msg = "Negative heights")
#> ✔ Check passed: Negative heights
```

When violations exist you choose the severity. The default is a warning,
which lets the pipeline continue but leaves a visible trace. The message
says how many rows broke the rule and shows the first few:

``` r
mtcars |>
  filter(mpg > 30) |>
  expect_empty(warn_msg = "Suspiciously fuel-efficient cars")
#> Warning in expect_empty(filter(mtcars, mpg > 30), warn_msg = "Suspiciously fuel-efficient cars"): Suspiciously fuel-efficient cars
#> ℹ 4 rows found:
#>   mpg = 32.4, cyl = 4, disp = 78.7, hp = 66, drat = 4.08, wt = 2.2, qsec =
#>   19.47, vs = 1, am = 1, g...
#>   mpg = 30.4, cyl = 4, disp = 75.7, hp = 52, drat = 4.93, wt = 1.615, qsec =
#>   18.52, vs = 1, am = 1,...
#>   mpg = 33.9, cyl = 4, disp = 71.1, hp = 65, drat = 4.22, wt = 1.835, qsec =
#>   19.9, vs = 1, am = 1, ...
#>   mpg = 30.4, cyl = 4, disp = 95.1, hp = 113, drat = 3.77, wt = 1.513, qsec =
#>   16.9, vs = 1, am = 1,...
```

For assumptions the rest of the pipeline depends on, escalate to a hard
stop with `abort_msg`:

``` r
df |>
  filter(is.na(id)) |>
  expect_empty(abort_msg = "Rows without an id, cannot continue")
#> Error in `expect_empty()`:
#> ! Rows without an id, cannot continue
#> ℹ 2 rows found:
#>   id = NA, amount = 120
#>   id = NA, amount = -4
```

Messages are shown literally, so a regular expression such as
`"CVR must match ^\\d{8}$"` is safe in a message.

## Checks in the middle of a pipeline: `expect_none()`

[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
returns what it was given, which after a
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html) is the
(empty) violation set. That ends the pipeline.
[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)
takes the condition itself and returns the *full* data, so checks can be
chained before the real work continues:

``` r
starwars |>
  expect_none(height < 0) |>
  expect_none(mass > 1000, warn_msg = "Unrealistic mass") |>
  count(species, sort = TRUE) |>
  head(3)
#> ✔ No rows where height < 0
#> Warning in expect_none(expect_none(starwars, height < 0), mass > 1000, warn_msg = "Unrealistic mass"): Unrealistic mass
#> ℹ 1 row found:
#>   name = "Jabba Desilijic Tiure", height = 175, mass = 1358, hair_color = NA,
#>   skin_color = "green-t...
#> # A tibble: 3 × 2
#>   species     n
#>   <chr>   <int>
#> 1 Human      35
#> 2 Droid       6
#> 3 NA          4
```

Without a message, the condition itself becomes one, which is often
enough during exploration. Give checks that stay in production a message
in your own words.

The condition follows
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html)
semantics: a row where it is `NA` is not a violation. `mass > 1000` does
not flag characters with unknown mass; test for missing values
explicitly with [`is.na()`](https://rdrr.io/r/base/NA.html) when they
matter.

## Anything dplyr can express is a rule

Some checkpoints from register work:

``` r
# Identifiers must look right (%like% preserves NA, unlike grepl)
df |>
  expect_none(!cvr %like% "^\\d{8}$", abort_msg = "Malformed CVR numbers")

# CPR numbers must hold a real date of birth
df |>
  add_cpr_info(cpr, valid) |>
  expect_none(!valid, warn_msg = "Invalid CPR numbers")

# Spells must not end before they start
spells |>
  expect_none(end < start, abort_msg = "Spells ending before they start")

# Amounts must reconcile within tolerance
df |>
  expect_none(abs(total - rowSums(across(starts_with("post_")))) > 1,
              warn_msg = "Totals do not reconcile")

# Categorical values must be in the codebook
df |>
  expect_none(!branche %in% codebook$branche, abort_msg = "Unknown industry codes")

# Every expected unit must be present (anti-join as violation set)
expected |>
  anti_join(df, by = "cvr") |>
  expect_empty(warn_msg = "Units missing from the delivery")
```

## Keys: `expect_unique()`

Duplicate keys are the most common error in register data, and the most
costly one sits right before a join. A lookup table with a duplicated
key makes
[`left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
multiply rows without a word. Check the key first:

``` r
df <- tibble(
  cvr  = c("11111111", "22222222", "11111111"),
  year = c(2024, 2024, 2024)
)

df |>
  expect_unique(cvr, year, warn_msg = "Duplicate company-years")
#> Warning in expect_unique(df, cvr, year, warn_msg = "Duplicate company-years"): Duplicate company-years
#> ℹ 2 rows found:
#>   dupid = 1, cvr = "11111111", year = 2024
#>   dupid = 1, cvr = "11111111", year = 2024
```

The reported rows carry the `dupid` from
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md),
so the copies in each group sit together. Outside of checkpoints,
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
is the tool for *inspecting* duplicates before deciding what to do with
them.

## Panels: `expect_balanced()`

A yearly register extract is a panel: one row per person (or company)
and year. Whether it is *balanced*, every unit present in every year,
decides which methods are valid and often reveals a broken extract.

``` r
panel <- tibble(
  cpr  = c("a", "a", "a", "b", "b", "c"),
  year = c(2020, 2021, 2022, 2020, 2022, 2022)
)

expect_balanced(panel, cpr, year)
#> Warning in expect_balanced(panel, cpr, year): Panel is not balanced: missing cpr-year combinations
#> ℹ 3 rows found:
#>   cpr = "b", year = 2021
#>   cpr = "c", year = 2020
#>   cpr = "c", year = 2021
```

Real populations are rarely balanced. People are born, die and migrate.
What usually *should* hold is that a unit, once present, does not skip a
year before it leaves. `gaps_only = TRUE` checks that: `c` entering in
2022 is fine, `b` missing in 2021 is not.

``` r
expect_balanced(panel, cpr, year, gaps_only = TRUE)
#> Warning in expect_balanced(panel, cpr, year, gaps_only = TRUE): Gaps in panel: missing cpr-year combinations
#> ℹ 1 row found:
#>   cpr = "b", year = 2021
```

By default the expected years are those found in the data, so a year
that was never loaded goes unnoticed. State the years you expect to
catch that as well:

``` r
expect_balanced(panel, cpr, year, periods = 2015:2024, gaps_only = TRUE)
```

## Spells: `expect_no_overlap()`

The other shape of register data is spells: address periods, employment,
benefit periods. A person has only one address at a time, so overlapping
spells within a person are an error:

``` r
addresses <- tibble(
  cpr   = c("a", "a", "b", "b"),
  start = as.Date(c("2020-01-01", "2021-01-01", "2020-01-01", "2020-06-01")),
  end   = as.Date(c("2020-12-31", NA,           "2020-06-30", "2021-12-31"))
)

expect_no_overlap(addresses, cpr, start, end)
#> Warning in expect_no_overlap(addresses, cpr, start, end): Overlapping spells per cpr
#> ℹ 2 rows found:
#>   overlap_id = 1, cpr = "b", start = 2020-01-01, end = 2020-06-30
#>   overlap_id = 1, cpr = "b", start = 2020-06-01, end = 2021-12-31
```

Spells are closed intervals, and a missing end means the spell is
ongoing. The reported rows carry an `overlap_id` that groups spells
overlapping each other, the same idea as `dupid`.

## Column types: `view_types()` + `expect_empty()`

Joins and row-binds have their own silent failure mode: the same column
arriving as `chr` in one data frame and `dbl` in the next.
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
shows the type of every column across several data frames at once:

``` r
df_a <- tibble(cvr = "11111111", amount = 100,   year = 2024L)
df_b <- tibble(cvr = 22222222,  amount = "100", note = "ok")

view_types(df_a, df_b)
#> # A tibble: 4 × 3
#>   column df_a  df_b 
#>   <chr>  <chr> <chr>
#> 1 cvr    chr   dbl  
#> 2 amount dbl   chr  
#> 3 year   int   NA   
#> 4 note   NA    chr
```

With `diff = TRUE` only the disagreeing columns remain, so compatible
frames produce an *empty* result, ready for a checkpoint:

``` r
view_types(df_a, df_b, diff = TRUE) |>
  expect_empty(warn_msg = "Column types differ between df_a and df_b")
#> Warning in expect_empty(view_types(df_a, df_b, diff = TRUE), warn_msg = "Column types differ between df_a and df_b"): Column types differ between df_a and df_b
#> ℹ 4 rows found:
#>   column = "cvr", df_a = "chr", df_b = "dbl"
#>   column = "amount", df_a = "dbl", df_b = "chr"
#>   column = "year", df_a = "int", df_b = NA
#>   column = "note", df_a = NA, df_b = "chr"
```

## Many rules at once: `tally_violations()`

A chain of checkpoints stops at the first abort. When a delivery has
five problems, you want to hear about all five in one go, not one per
run.

To *tally* is to keep count, as with tally marks or
[`dplyr::tally()`](https://dplyr.tidyverse.org/reference/count.html).
That is the whole idea of
[`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md):
it evaluates every rule and counts the violating rows, but never warns
or stops. Counting and judging are kept apart. The `expect_*()`
functions judge; the tally only counts, and severity is decided
afterwards.

``` r
report <- starwars |>
  tally_violations(
    "Missing species"   = is.na(species),
    "Taller than 2.5 m" = height > 250,
    "Heavier than 1 t"  = mass > 1000,
    "Negative height"   = height < 0
  )
report
#> # A tibble: 4 × 3
#>   rule                  n rows     
#>   <chr>             <int> <list>   
#> 1 Missing species       4 <int [4]>
#> 2 Taller than 2.5 m     1 <int [1]>
#> 3 Heavier than 1 t      1 <int [1]>
#> 4 Negative height       0 <int [0]>
```

The `rows` column holds the row numbers of each rule’s violations, for
`starwars[report$rows[[1]], ]`. Filtered to the rules that failed, the
tally is itself a violation set, so it goes straight into a checkpoint:

``` r
report |>
  filter(n > 0) |>
  expect_empty(warn_msg = "The data failed validation")
#> Warning in expect_empty(filter(report, n > 0), warn_msg = "The data failed validation"): The data failed validation
#> ℹ 3 rows found:
#>   rule = "Missing species", n = 4, rows = [18, 59, 60, 81]
#>   rule = "Taller than 2.5 m", n = 1, rows = [56]
#>   rule = "Heavier than 1 t", n = 1, rows = [16]
```

Kept unfiltered, it is a validation report that can be sent back to
whoever made the data: `report |> select(-rows) |> write_excel(...)`.

## Unattended pipelines: log, dump and catch

For pipelines that run unattended, every checkpoint can append a line to
a log and write the offending rows to a CSV file. Set both once at the
top of the script with options instead of repeating the paths in every
check:

``` r
options(
  daos.check_log  = f("log/{nowf()}_checks.log"),
  daos.check_dump = "log/violations"
)

df |>
  expect_none(is.na(id), abort_msg = "NA ids") |>
  expect_none(amount < 0, warn_msg = "Negative amounts") |>
  expect_unique(id, year, warn_msg = "Duplicate person-years")
```

    2026-06-11 09:00:03 | ✔ | Check passed: NA ids | 0 rows
    2026-06-11 09:00:03 | ! | Negative amounts | 3 rows | log/violations/20260611_090003_Negative_amounts.csv
    2026-06-11 09:00:04 | ✔ | Check passed: Duplicate person-years | 0 rows

Each check that ran is named in the log, failures say how many rows
broke the rule, and the rows themselves are waiting in the dump
directory. The CSV files are written with a byte order mark, so Excel
shows æ, ø and å correctly.

A failed check signals a condition of class `daos_check_failure` that
carries the offending rows in `$violations`. Code that should react to a
failure, rather than just stop, can catch it:

``` r
tryCatch(
  df |> expect_none(is.na(id), abort_msg = "NA ids"),
  daos_check_failure = \(e) {
    saveRDS(e$violations, "na_ids.rds")
    stop(e)
  }
)
```

## The same idea inside the package

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
uses exactly this philosophy internally: every path is validated before
a single file is opened, and all the missing or unreadable ones are
reported together rather than one abort at a time. If you adopt one
habit from this article, make it that one: validate *before* you write
output, and make the empty set the definition of success.
