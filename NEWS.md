# daos (development version)

* `read_workbook()` reads every sheet of an Excel workbook into a named
  list, finding the table on each sheet instead of reading every non-empty
  cell: titles, source notes and stray comments are left out, and one
  warning lists what was left behind. Choose the area yourself with
  `range`, one per sheet if needed, or a named range from the workbook
  (`range = "Sales"`), or read defined Excel tables by name with `table`. A password-protected workbook gives a clear error.

* `inspect_excel()` lists the blocks of cells outside the table as a
  tibble, empty when the layout is clean.

* `read_files()` is quiet on success and reports problems together:
  * CSV files no longer print the locale and column specification for every
    file. The decimal comma is kept when you pass a `locale` for its
    encoding.
  * A file that fails to read no longer stops the rest; all failures are
    reported in one error, each with its file. Unsupported extensions are
    caught before anything is read, missing files are listed with their full
    path (at most ten), and multi-sheet workbooks give one warning in all.
  * `out = "bind"` re-types only the columns whose types clash, and names
    them in the warning, instead of re-guessing every column. Files that do
    not read as data frames give a clear error.
  * Files that share a name give a warning, and an error with
    `out = "unpack"`. A name in `paths` on a pattern that expands to several
    files is an error instead of being silently dropped.

* The validation checkpoints have moved to their own package, expectr:
  `expect_empty()`, `expect_none()`, `expect_unique()`, `expect_balanced()`,
  `expect_no_overlap()` and `tally_violations()`. daos forwards each of
  them to expectr and says so once per session; the options
  `daos.check_log` and `daos.check_dump` and the condition class
  `daos_check_failure` keep working. Use `library(expectr)` in new code.
  In expectr, the checkpoints are much faster on population-sized data and
  also check DuckDB and Arrow tables.

* The inspection helpers `flag_duplicates()` and `view_types()` stay in
  daos. `flag_duplicates()` now groups the key in one linear pass without
  sorting it: about 11 times faster on 5 million rows keyed by cpr and
  year.

* `spells_to_panel()` turns spell data (education, addresses) into a
  yearly, quarterly or monthly panel with primo and ultimo status, and
  `add_spell_status()` adds the same status to a panel you already have, or
  the status on a date. Rows are never added or dropped, also when spells
  overlap; both share one compiled lookup.

* Validation checkpoints are extended into a small family that shares one
  engine (`vignette("validation")`):
  * `expect_none()` checks a condition and returns the full data, so checks
    can be chained mid-pipeline.
  * `expect_unique()` checks keys, e.g. before a join.
  * `expect_balanced()` checks that a register panel is balanced, or with
    `gaps_only = TRUE` that units do not skip periods.
  * `expect_no_overlap()` checks that spells (addresses, employment) do not
    overlap within a unit.
  * `tally_violations()` counts violations for many rules at once without
    warning or aborting; filter and pipe it into `expect_empty()` to judge.

* `expect_empty()` failure messages now give the row count and preview the
  first rows. Messages are shown literally (braces are no longer
  interpolated). With `warn_msg` or `abort_msg` set, the success message
  defaults to `"Check passed: <message>"`, so the log names every check.
  Failures signal class `daos_check_failure` with the rows in
  `$violations`. Log lines now include the row count. New `dump` argument
  writes offending rows to CSV; `log` and `dump` default to the options
  `daos.check_log` and `daos.check_dump`.

* `age(year)` defaults to `primo = "previous_ultimo"`: opening ages on
  31 December of the previous year. Use `primo = "jan1"` for 1 January ages.

* `write_excel()` gains `digits`: keep zero displayed decimals by default,
  choose a different precision, or use `NULL` to disable automatic numeric
  formatting. Stored values are unchanged.

* Consolidate Excel writing in `write_excel(mode = ...)`: `new` (default),
  `append`, `replace` (matching sheets), and `overwrite` (entire workbook).
  Remove `append_excel()` and the former `overwrite` argument.

* Excel exports now write numeric missing values as blank cells and handle
  all-missing numeric columns without warnings. Invalid or duplicate sheet
  names and invalid list inputs are rejected before writing. `mode = "replace"`
  matches sheet names ignoring case and preserves replaced sheets' positions.

* Add `inspect_db()` to diagnose mixed full DB07/DB25 codes, returning key
  membership and both labels. Shared codes remain unresolved, even if labels
  match; unknown and missing codes receive explicit statuses.

* Add `db_label()` to look up Danish industry titles from bundled DST tables
  for DB25 or DB07, including hierarchy codes. Requires an explicit `version`.
  Accepts dotted or compact input; unknown codes warn and return `NA`.

* Add `convert_db07_to_db25()` and `convert_db25_to_db07()` using bundled
  DST keys (source page updated 26 February 2026). Both accept mixed code
  formatting and offer dotted or compact output. The default strict method
  warns and returns `NA` for splits; `method = "simple"` uses DST's separate
  approximate matrix for each direction. Invalid or unknown full codes also
  warn and return `NA`.

* `add_cpr_info()` now accepts selections such as `sex`, `bday`, and
  `alder = age(year, "ultimo")`. Multiple age references work in one call.
  This replaces the `add`, `ref_date`, `year`, and `at` arguments.
* `age(year)` uses the previous 31 December; `age(date = ...)` accepts an explicit date.
  Bare `age` uses today. Default output still includes all five information types.
* `add_cpr_info()` preserves the source CPR column. Use `clean_cpr()`
  explicitly to standardise it. Existing output columns require
  `overwrite = TRUE`; duplicate output names and replacing the source CPR
  column are errors.

* CPR cleaning and derivation now share a registered native C kernel. Each
  CPR is parsed once per `add_cpr_info()` call, including multiple ages;
  modulus-11 no longer allocates a digit matrix. ISO reference dates are
  validated directly without parsing and formatting them through POSIXlt.
* `clean_cpr()` returns already standardised character vectors without
  copying them. Cleaning remains optional before `add_cpr_info()` and is
  useful when standardising identifiers for joins or export.
* Source installations now require a C compiler (Rtools on Windows).

* Replace the experimental `drop_all_na()` with `drop_empty_rows()` and
  `drop_empty_cols()`. Both accept tidyselect column selections, including
  `where(is.numeric)`, plus `blank = TRUE` for empty/whitespace-only text.
