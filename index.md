[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/daos)

> **Experimental.** This package is a personal collection of utility
> functions that have grown out of day-to-day statistical work: things I
> kept wishing R had out of the box, patterns I found myself repeating,
> and new ideas I wanted to try out. Rather than letting them accumulate
> as loose scripts, I packaged them up properly with the help of Claude
> Code to get a solid starting point: documentation, tests, and a
> vignette from the start. Consider it a living experiment.

## Installation

``` r

pak::pak("dataniel/daos")
```

## Functions

| Function | Description |
|----|----|
| `%??%` | Null-coalescing operator that returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| [`accounts_pdf_to_txt()`](https://dataniel.github.io/daos/reference/accounts_pdf_to_txt.md) | Convert PDF financial statements to text files |
| [`addin_fix_path()`](https://dataniel.github.io/daos/reference/addin_fix_path.md) | RStudio addin: replace backslashes with forward slashes in Windows paths |
| [`addin_paste_path()`](https://dataniel.github.io/daos/reference/addin_paste_path.md) | RStudio addin: paste Windows path from clipboard as a quoted R string |
| [`addin_flip_backslash()`](https://dataniel.github.io/daos/reference/addin_flip_backslash.md) | RStudio addin: replace all backslashes with forward slashes in selection |
| [`addin_open_in_explorer()`](https://dataniel.github.io/daos/reference/addin_open_in_explorer.md) | RStudio addin: open the selected path (or [`getwd()`](https://rdrr.io/r/base/getwd.html)) in the file explorer |
| [`addin_text_to_vector()`](https://dataniel.github.io/daos/reference/addin_text_to_vector.md) | RStudio addin: convert selected lines to an R character vector |
| [`accounts_txt_to_xlsx()`](https://dataniel.github.io/daos/reference/accounts_txt_to_xlsx.md) | Parse manually formatted text files and export to Excel |
| [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md) | Add birth date, age, sex, and validity derived from Danish CPR numbers |
| [`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md) | Standardise CPR numbers: strip separators, restore Excel-lost leading zeros |
| [`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md) | Standardise CVR numbers: strip separators and the DK VAT prefix |
| [`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md) | Build an Elasticsearch query for CVR annual reports |
| [`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md) | Send a query to the CVR distribution service |
| [`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md) | Extract CVR search hits as a tibble |
| [`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md) | Download the documents found by a CVR search |
| [`dbdot()`](https://dataniel.github.io/daos/reference/dbdot.md) | Format DB07 industry codes with dots (`011100` → `01.11.00`) |
| [`drop_all_na()`](https://dataniel.github.io/daos/reference/drop_all_na.md) | Drop rows and/or columns that are entirely `NA` |
| [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md) | Pipeline checkpoint that warns or aborts if a data frame is non-empty |
| [`f()`](https://dataniel.github.io/daos/reference/f.md) | String interpolation shorthand ([`glue::glue`](https://glue.tidyverse.org/reference/glue.html) alias) |
| [`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md) | Find sign assignments that reconcile a set of values to a total |
| [`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md) | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| [`is_blank()`](https://dataniel.github.io/daos/reference/is_blank.md) | Test whether a value is blank in the broadest sense |
| [`nowf()`](https://dataniel.github.io/daos/reference/nowf.md) | Formatted current timestamp, e.g. for file names |
| [`read_access()`](https://dataniel.github.io/daos/reference/read_access.md) | Read data from a Microsoft Access database via ODBC |
| [`read_files()`](https://dataniel.github.io/daos/reference/read_files.md) | Validate paths, read files (auto or custom reader), and optionally bind or unpack |
| [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md) | Read Greenlandic TA files |
| [`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md) | Write Greenlandic TA files |
| [`read_xbrl()`](https://dataniel.github.io/daos/reference/read_xbrl.md) | Parse an XBRL file into a tidy tibble |
| [`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md) | Interactive Shiny dashboard for screening time-series data group by group |
| [`shh()`](https://dataniel.github.io/daos/reference/shh.md) | Suppress messages and warnings during evaluation |
| [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md) | Split a data frame into a named list by grouping columns |
| [`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md) | Shiny explorer for the Greenland and Faroese statbanks: browse, select, preview, and copy R code |
| [`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md) | Download a Greenland or Faroese statbank table as a tidy tibble |
| [`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md) | Get a statbank table’s variables and values |
| [`statbank_nodes()`](https://dataniel.github.io/daos/reference/statbank_nodes.md) | Browse one level of the statbank table tree |
| [`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md) | Search statbank tables by title |
| [`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md) | List every table in the statbank (cached per session) |
| [`summon()`](https://dataniel.github.io/daos/reference/summon.md) | Retrieve objects matching a regex pattern from an environment |
| [`view_types()`](https://dataniel.github.io/daos/reference/view_types.md) | Compare column types across multiple data frames |
| [`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md) | Write data frames to a presentable xlsx: bold frozen header, thousand separators, blank NAs |
| [`append_excel()`](https://dataniel.github.io/daos/reference/append_excel.md) | Append formatted sheets to an existing xlsx file |
