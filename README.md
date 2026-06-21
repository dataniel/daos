# daos

[![R-CMD-check](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dataniel/daos/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://dataniel.github.io/daos)

> **Experimental.** This package is a personal collection of utility functions
> that have grown out of day-to-day statistical work: things I kept wishing R
> had out of the box, patterns I found myself repeating, and new ideas I wanted
> to try out. Rather than letting them accumulate as loose scripts, I packaged
> them up properly with the help of Claude Code to
> get a solid starting point: documentation, tests, and a vignette from the
> start. Consider it a living experiment.

## Installation

```r
pak::pak("dataniel/daos")
```

## Functions

| Function | Description |
|----------|-------------|
| `%??%` | Null-coalescing operator that returns a default when `x` is `NULL`, empty, all-`NA`, or all-`""` |
| `%like%` | Regex matching that preserves `NA` (unlike `grepl`) |
| `accounts_pdf_to_txt()` | Convert PDF financial statements to text files |
| `addin_fix_path()` | RStudio addin: replace backslashes with forward slashes in Windows paths |
| `addin_paste_path()` | RStudio addin: paste Windows path from clipboard as a quoted R string |
| `addin_flip_backslash()` | RStudio addin: replace all backslashes with forward slashes in selection |
| `addin_open_in_explorer()` | RStudio addin: open the selected path (or `getwd()`) in the file explorer |
| `addin_text_to_vector()` | RStudio addin: convert selected lines to an R character vector |
| `accounts_txt_to_xlsx()` | Parse manually formatted text files and export to Excel |
| `add_cpr_info()` | Add birth date, age, sex, and validity derived from Danish CPR numbers |
| `browse_files()` | Yazi-style Shiny file browser: mark files/folders and copy paths to R |
| `clean_cpr()` | Standardise CPR numbers: strip separators, restore Excel-lost leading zeros |
| `clean_cvr()` | Standardise CVR numbers: strip separators and the DK VAT prefix |
| `cvr_query()` | Build an Elasticsearch query for CVR annual reports |
| `cvr_search()` | Send a query to the CVR distribution service |
| `cvr_hits()` | Extract CVR search hits as a tibble |
| `cvr_download()` | Download the documents found by a CVR search |
| `dbdot()` | Format DB07 industry codes with dots (`011100` → `01.11.00`) |
| `drop_all_na()` | Drop rows and/or columns that are entirely `NA` |
| `expect_empty()` | Pipeline checkpoint that warns or aborts if a data frame is non-empty |
| `f()` | String interpolation shorthand (`glue::glue` alias) |
| `find_signs()` | Find sign assignments that reconcile a set of values to a total |
| `flag_duplicates()` | Prepend `isdup`/`dupid` columns to mark duplicate rows |
| `is_blank()` | Test whether a value is blank in the broadest sense |
| `nowf()` | Formatted current timestamp, e.g. for file names |
| `read_access()` | Read data from a Microsoft Access database via ODBC |
| `read_files()` | Validate paths, read files (auto or custom reader), and optionally bind or unpack |
| `read_ta()` | Read Greenlandic TA files |
| `write_ta()` | Write Greenlandic TA files |
| `read_xbrl()` | Parse an XBRL file into a tidy tibble |
| `screen_timeseries()` | Interactive Shiny dashboard for screening time-series data group by group |
| `shh()` | Suppress messages and warnings during evaluation |
| `split_by()` | Split a data frame into a named list by grouping columns |
| `statbank_app()` | Shiny explorer for the Greenland and Faroese statbanks: browse, select, preview, and copy R code |
| `statbank_get()` | Download a Greenland or Faroese statbank table as a tidy tibble |
| `statbank_meta()` | Get a statbank table's variables and values |
| `statbank_nodes()` | Browse one level of the statbank table tree |
| `statbank_search()` | Search statbank tables by title |
| `statbank_tables()` | List every table in the statbank (cached per session) |
| `summon()` | Retrieve objects matching a regex pattern from an environment |
| `task_db()` | Create/open a shared SQLite task database (WAL, multi-user) |
| `task_add()` | Add a task (key, project, assignee, tags, priority, due, recurrence, dependencies) |
| `task_cycle()` | Register a production cycle as a chain of dependent steps |
| `task_list()` | List tasks with tags, blocked flag, started flag, and urgency |
| `task_get()` / `task_require()` / `task_blockers()` | Fetch a task by id, uuid, or key; gate a script on upstream tasks; see what blocks a task |
| `task_start()` / `task_stop()` / `task_step()` | Mark a task in progress, stop it, or run a production step under it |
| `task_done()` / `task_reopen()` / `task_delete()` / `task_modify()` | Complete, reopen, soft-delete, or edit a task |
| `task_purge()` | Permanently remove soft-deleted tasks (empty the trash) |
| `task_annotate()` | Add a timestamped note to a task |
| `task_projects()` | Per-project manager overview: health, in-progress, blocked, overdue, stalled, next deadline |
| `task_people()` | Per-person load: pending, in progress, blocked, overdue, recently done |
| `task_bottlenecks()` / `task_activity()` | The tasks blocking the most others; a newest-first activity feed |
| `task_app()` | Shiny task manager over a shared task database |
| `view_types()` | Compare column types across multiple data frames |
| `write_excel()` | Write data frames to a presentable xlsx: bold frozen header, thousand separators, blank NAs |
| `append_excel()` | Append formatted sheets to an existing xlsx file |
