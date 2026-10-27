# Package index

## General utilities

- [`f()`](https://dataniel.github.io/daos/reference/f.md) : String
  interpolation shorthand

- [`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) :
  Formatted timestamp for now

- [`shh()`](https://dataniel.github.io/daos/reference/shh.md) : Suppress
  messages and warnings

- [`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md)
  : Test whether a value is "blank"

- [`` `%??%` ``](https://dataniel.github.io/daos/reference/grapes-help-help-grapes.md)
  : Extended null-coalescing operator

- [`` `%like%` ``](https://dataniel.github.io/daos/reference/grapes-like-grapes.md)
  :

  Regex matching with `NA` preservation

## File workflow

- [`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
  : Read one or more files
- [`read_access()`](https://dataniel.github.io/daos/reference/read_access.md)
  : Read data from a Microsoft Access database
- [`summon()`](https://dataniel.github.io/daos/reference/summon.md) :
  Retrieve objects matching a pattern from an environment
- [`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
  : Write data frames to a presentable Excel file

## Data wrangling

- [`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
  : Compare column types across data frames
- [`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
  : Flag duplicate rows
- [`diagnose_timeseries()`](https://dataniel.github.io/daos/reference/diagnose_timeseries.md)
  : Diagnose time series, optionally within dplyr groups
- [`drop_empty_rows()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md)
  [`drop_empty_cols()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md)
  : Drop rows or columns that are empty in selected columns
- [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)
  : Split a data frame into a named list by grouping columns

## Validation checkpoints

State a rule as “the set of violations must be empty”. The `expect_*()`
functions judge a rule and warn or abort;
[`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md)
only counts violations for many rules, so you decide on severity
afterwards. See
[`vignette("validation")`](https://dataniel.github.io/daos/articles/validation.md).

- [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
  : Assert that a data frame is empty
- [`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)
  : Assert that no rows match a condition
- [`expect_unique()`](https://dataniel.github.io/daos/reference/expect_unique.md)
  : Assert that key columns identify each row uniquely
- [`expect_balanced()`](https://dataniel.github.io/daos/reference/expect_balanced.md)
  : Assert that a panel is balanced, or has no gaps
- [`expect_no_overlap()`](https://dataniel.github.io/daos/reference/expect_no_overlap.md)
  : Assert that spells do not overlap within a unit
- [`tally_violations()`](https://dataniel.github.io/daos/reference/tally_violations.md)
  : Count violations for several rules at once

## Interactive

- [`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
  : Interactive time-series screening dashboard

## Danish and Greenlandic data

- [`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
  : Standardise CPR numbers
- [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  : Add information derived from Danish CPR numbers
- [`age()`](https://dataniel.github.io/daos/reference/age.md) : Specify
  an age calculation for CPR information
- [`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md)
  : Standardise CVR numbers
- [`format_db07()`](https://dataniel.github.io/daos/reference/format_db07.md)
  : Format DB07 industry codes
- [`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
  [`convert_db25_to_db07()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
  : Convert industry codes between DB07 and DB25 using Statistics
  Denmark's keys
- [`db_label()`](https://dataniel.github.io/daos/reference/db_label.md)
  : Look up Danish industry labels for DB07 or DB25 codes
- [`inspect_db()`](https://dataniel.github.io/daos/reference/inspect_db.md)
  : Inspect possible classifications of mixed DB07 and DB25 industry
  codes
- [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md) :
  Read a Greenlandic TA file
- [`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md)
  : Write a Greenlandic TA file
- [`read_ta2()`](https://dataniel.github.io/daos/reference/read_ta2.md)
  : Read a Greenlandic TA file in the new layout
- [`write_ta2()`](https://dataniel.github.io/daos/reference/write_ta2.md)
  : Write a Greenlandic TA file in the new layout
