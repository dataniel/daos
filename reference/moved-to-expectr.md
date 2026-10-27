# Checkpoints, now in the expectr package

The validation checkpoints and their helpers moved from daos to the
expectr package:
[`expectr::expect_empty()`](https://dataniel.github.io/expectr/reference/expect_empty.html),
[`expectr::expect_none()`](https://dataniel.github.io/expectr/reference/expect_none.html),
[`expectr::expect_unique()`](https://dataniel.github.io/expectr/reference/expect_unique.html),
[`expectr::expect_balanced()`](https://dataniel.github.io/expectr/reference/expect_balanced.html),
[`expectr::expect_no_overlap()`](https://dataniel.github.io/expectr/reference/expect_no_overlap.html),
[`expectr::tally_violations()`](https://dataniel.github.io/expectr/reference/tally_violations.html),
[`expectr::flag_duplicates()`](https://dataniel.github.io/expectr/reference/flag_duplicates.html)
and
[`expectr::view_types()`](https://dataniel.github.io/expectr/reference/view_types.html).
They share an engine and a contract the rest of daos does not, so they
are developed there. See
[`vignette("expectr", package = "expectr")`](https://dataniel.github.io/expectr/articles/expectr.html).

## Usage

``` r
expect_empty(...)

expect_none(...)

expect_unique(...)

expect_balanced(...)

expect_no_overlap(...)

tally_violations(...)

flag_duplicates(...)

view_types(...)
```

## Arguments

- ...:

  Passed on to the expectr function of the same name.

## Value

What the expectr function returns.

## Details

daos keeps a function of the same name for each, so existing scripts
keep working. It calls expectr, says once per session that the function
has moved, and keeps the old names working:

- `options(daos.check_log = , daos.check_dump = )` are used when the new
  `expectr.log` and `expectr.dump` are not set.

- A failed check also carries the old condition class
  `daos_check_failure`, so `tryCatch(daos_check_failure = )` still
  catches it.

New code should call expectr directly, e.g. with
[`library(expectr)`](https://dataniel.github.io/expectr).
