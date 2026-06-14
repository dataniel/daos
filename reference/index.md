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
- [`summon()`](https://dataniel.github.io/daos/reference/summon.md) :
  Retrieve objects matching a pattern from an environment
- [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md) :
  Read a Greenlandic TA file
- [`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md)
  : Write a Greenlandic TA file
- [`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
  : Write data frames to a presentable Excel file
- [`append_excel()`](https://dataniel.github.io/daos/reference/append_excel.md)
  : Append sheets to an existing Excel file

## Data wrangling

- [`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
  : Compare column types across data frames

- [`flag_duplicates()`](https://dataniel.github.io/daos/reference/flag_duplicates.md)
  : Flag duplicate rows

- [`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md)
  : Assert that a data frame is empty

- [`drop_all_na()`](https://dataniel.github.io/daos/reference/drop_all_na.md)
  :

  Drop all-`NA` rows and/or columns

- [`split_by()`](https://dataniel.github.io/daos/reference/split_by.md)
  : Split a data frame into a named list by grouping columns

- [`find_signs()`](https://dataniel.github.io/daos/reference/find_signs.md)
  : Find sign combinations that sum to a target

## Interactive

- [`screen_timeseries()`](https://dataniel.github.io/daos/reference/screen_timeseries.md)
  : Interactive time-series screening dashboard
- [`browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md)
  : Browse the filesystem and copy paths to R

## Domain-specific

- [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  : Add information derived from Danish CPR numbers
- [`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
  : Standardise CPR numbers
- [`clean_cvr()`](https://dataniel.github.io/daos/reference/clean_cvr.md)
  : Standardise CVR numbers
- [`dbdot()`](https://dataniel.github.io/daos/reference/dbdot.md) :
  Format DB07 industry codes with dots
- [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md) :
  Read a Greenlandic TA file
- [`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md)
  : Write a Greenlandic TA file

## File readers

- [`read_access()`](https://dataniel.github.io/daos/reference/read_access.md)
  : Read data from a Microsoft Access database
- [`read_xbrl()`](https://dataniel.github.io/daos/reference/read_xbrl.md)
  : Read an XBRL file
- [`accounts_pdf_to_txt()`](https://dataniel.github.io/daos/reference/accounts_pdf_to_txt.md)
  : Convert PDF files to text files
- [`accounts_txt_to_xlsx()`](https://dataniel.github.io/daos/reference/accounts_txt_to_xlsx.md)
  : Parse formatted text files and export to Excel

## CVR annual reports

- [`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md)
  : Build an Elasticsearch query for CVR annual reports
- [`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)
  : Send a query to the CVR distribution service
- [`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md)
  : Extract CVR search hits as a tibble
- [`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)
  : Download CVR documents

## Task manager

- [`task_app()`](https://dataniel.github.io/daos/reference/task_app.md)
  : Task manager app
- [`task_db()`](https://dataniel.github.io/daos/reference/task_db.md) :
  Create or open a shared task database
- [`task_add()`](https://dataniel.github.io/daos/reference/task_add.md)
  : Add a task
- [`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
  : List tasks
- [`task_get()`](https://dataniel.github.io/daos/reference/task_get.md)
  : Get one or more tasks by id
- [`task_require()`](https://dataniel.github.io/daos/reference/task_require.md)
  : Require tasks to have a given status
- [`task_blockers()`](https://dataniel.github.io/daos/reference/task_blockers.md)
  : Why a task is blocked
- [`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)
  : Complete a task
- [`task_reopen()`](https://dataniel.github.io/daos/reference/task_reopen.md)
  : Reopen a task
- [`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md)
  : Delete a task
- [`task_modify()`](https://dataniel.github.io/daos/reference/task_modify.md)
  : Modify a task
- [`task_annotate()`](https://dataniel.github.io/daos/reference/task_annotate.md)
  : Annotate a task
- [`task_annotations()`](https://dataniel.github.io/daos/reference/task_annotations.md)
  : Annotations of a task
- [`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md)
  : Project overview
- [`task_people()`](https://dataniel.github.io/daos/reference/task_people.md)
  : People overview

## Greenland Statbank

- [`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
  : Interactive explorer for the Greenland Statbank
- [`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)
  : Download a table from a statbank
- [`statbank_meta()`](https://dataniel.github.io/daos/reference/statbank_meta.md)
  : Get the metadata for a statbank table
- [`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md)
  : Search statbank tables by title
- [`statbank_tables()`](https://dataniel.github.io/daos/reference/statbank_tables.md)
  : List every table in a statbank
- [`statbank_nodes()`](https://dataniel.github.io/daos/reference/statbank_nodes.md)
  : List one level of a statbank table tree

## RStudio addins

- [`addin_fix_path()`](https://dataniel.github.io/daos/reference/addin_fix_path.md)
  : RStudio addin: fix Windows paths
- [`addin_flip_backslash()`](https://dataniel.github.io/daos/reference/addin_flip_backslash.md)
  : RStudio addin: flip backslashes in selection
- [`addin_open_in_explorer()`](https://dataniel.github.io/daos/reference/addin_open_in_explorer.md)
  : RStudio addin: open path in file explorer
- [`addin_paste_path()`](https://dataniel.github.io/daos/reference/addin_paste_path.md)
  : RStudio addin: paste path from clipboard
- [`addin_text_to_vector()`](https://dataniel.github.io/daos/reference/addin_text_to_vector.md)
  : RStudio addin: convert lines to R character vector
