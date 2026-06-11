# Lightweight data validation with checkpoints

Statistical production code lives or dies on small assumptions: no
duplicate units, no negative amounts, no rows missing an identifier. A
full validation framework is often more ceremony than the job needs. The
alternative is a *checkpoint*: one line that states the assumption and
stops the pipeline (or shouts) the moment it breaks.

The pattern is always the same:

> **Express the rule as “the set of violations must be empty”, build
> that set with an ordinary
> [`filter()`](https://dplyr.tidyverse.org/reference/filter.html), and
> pass it to
> [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md).**

## The checkpoint: `expect_empty()`

[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
succeeds when the data frame it receives has zero rows. Filter for the
rows that *should not exist*, and pipe them in:

``` r

starwars |>
  filter(height < 0) |>
  expect_empty(success_msg = "No negative heights")
#> ✔ No negative heights
```

When violations exist you choose the severity. The default is a warning,
which lets the pipeline continue but leaves a visible trace:

``` r

mtcars |>
  filter(mpg > 30) |>
  expect_empty(warn_msg = "Suspiciously fuel-efficient cars found")
#> Warning: Suspiciously fuel-efficient cars found
```

For assumptions the rest of the pipeline depends on, escalate to a hard
stop with `abort_msg`:

``` r

df |>
  filter(is.na(id)) |>
  expect_empty(abort_msg = "Rows without an id -- cannot continue")
#> Error in `expect_empty()`:
#> ! Rows without an id -- cannot continue
```

Because
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
returns its input invisibly, checkpoints can sit in the middle of a
pipeline without disturbing it.

## Anything `filter()` can express is a rule

The strength of the pattern is that the rule language is just dplyr.
Some checkpoints from real pipelines:

``` r

# Identifiers must look right (%like% preserves NA, unlike grepl)
df |> filter(!cvr %like% "^\\d{8}$") |>
  expect_empty(abort_msg = "Malformed CVR numbers")

# Amounts must reconcile within tolerance
df |> filter(abs(total - rowSums(across(starts_with("post_")))) > 1) |>
  expect_empty(warn_msg = "Totals do not reconcile")

# Categorical values must be in the codebook
df |> filter(!branche %in% codebook$branche) |>
  expect_empty(abort_msg = "Unknown industry codes")

# Every expected unit must be present (anti-join as violation set)
expected |> anti_join(df, by = "cvr") |>
  expect_empty(warn_msg = "Units missing from the delivery")
```

## Duplicates: `flag_duplicates()` + `expect_empty()`

Duplicate detection is the most common checkpoint of all, so it has a
dedicated helper.
[`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
prepends `isdup`/`dupid` columns; filtering on `isdup` turns it into a
violation set:

``` r

df <- tibble(
  cvr  = c("11111111", "22222222", "11111111"),
  year = c(2024, 2024, 2024)
)

df |>
  flag_duplicates(cvr, year) |>
  filter(isdup) |>
  expect_empty(warn_msg = "Duplicate company-years found")
#> Warning: Duplicate company-years found
```

Outside of checkpoints, the `dupid` column is also handy for
*inspecting* the duplicates pair by pair before deciding what to do with
them.

## An audit trail for scheduled pipelines

For pipelines that run unattended,
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
takes a `log` argument and appends one timestamped line per check – a
minimal audit trail without any logging framework:

``` r

log_path <- f("log/{nowf()}_checks.log")
check    <- \(data, ...) expect_empty(data, ..., log = log_path)

df |> filter(is.na(id))      |> check(abort_msg = "NA ids")
df |> filter(amount < 0)     |> check(warn_msg  = "Negative amounts")
df |> flag_duplicates(id) |> filter(isdup) |>
  check(warn_msg = "Duplicates")
```

    2026-06-11 09:00:03 | v The dataset is empty.
    2026-06-11 09:00:03 | ! Negative amounts
    2026-06-11 09:00:04 | v The dataset is empty.

Wrapping
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
in a small partial function like `check()` keeps the log path in one
place.

## The same idea inside the package

[`accounts_txt_to_xlsx()`](https://dataniel.github.io/daos/reference/accounts_txt_to_xlsx.md)
uses exactly this philosophy internally: every parsed company is checked
for malformed values, and all violations are collected and reported
together before anything is written. If you adopt one habit from this
article, make it that one – validate *before* you write output, and make
the empty set the definition of success.
