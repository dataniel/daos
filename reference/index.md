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

- [`diagnose_timeseries()`](https://dataniel.github.io/daos/reference/diagnose_timeseries.md)
  : Diagnose time series, optionally within dplyr groups
- [`drop_empty_rows()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md)
  [`drop_empty_cols()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md)
  : Drop rows or columns that are empty in selected columns
- [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)
  : Split a data frame into a named list by grouping columns
- [`spells_to_panel()`](https://dataniel.github.io/daos/reference/spells_to_panel.md)
  : Turn spell data into a period panel with primo and ultimo status
- [`add_spell_status()`](https://dataniel.github.io/daos/reference/add_spell_status.md)
  : Add status from spell data to a panel you already have

## Validation checkpoints

The checkpoints and their helpers have moved to the expectr package.
daos forwards them for existing scripts.

- [`expect_empty()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`expect_none()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`expect_unique()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`expect_balanced()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`expect_no_overlap()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`tally_violations()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`flag_duplicates()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  [`view_types()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  : Checkpoints, now in the expectr package

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
