# Changelog

## daos (development version)

- The validation checkpoints have moved to their own package, expectr:
  [`expect_empty()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`expect_none()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`expect_unique()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`expect_balanced()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`expect_no_overlap()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`tally_violations()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md),
  [`flag_duplicates()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  and
  [`view_types()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md).
  daos forwards each of them to expectr and says so once per session;
  the options `daos.check_log` and `daos.check_dump` and the condition
  class `daos_check_failure` keep working. Use
  [`library(expectr)`](https://dataniel.github.io/expectr) in new code.
  In expectr, the checkpoints are much faster on population-sized data
  and also check DuckDB and Arrow tables.

- [`spells_to_panel()`](https://dataniel.github.io/daos/reference/spells_to_panel.md)
  turns spell data (education, addresses) into a yearly, quarterly or
  monthly panel with primo and ultimo status, and
  [`add_spell_status()`](https://dataniel.github.io/daos/reference/add_spell_status.md)
  adds the same status to a panel you already have, or the status on a
  date. Rows are never added or dropped, also when spells overlap; both
  share one compiled lookup.

- Validation checkpoints are extended into a small family that shares
  one engine (`vignette("validation")`):

  - [`expect_none()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    checks a condition and returns the full data, so checks can be
    chained mid-pipeline.
  - [`expect_unique()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    checks keys, e.g. before a join.
  - [`expect_balanced()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    checks that a register panel is balanced, or with `gaps_only = TRUE`
    that units do not skip periods.
  - [`expect_no_overlap()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    checks that spells (addresses, employment) do not overlap within a
    unit.
  - [`tally_violations()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    counts violations for many rules at once without warning or
    aborting; filter and pipe it into
    [`expect_empty()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
    to judge.

- [`expect_empty()`](https://dataniel.github.io/daos/reference/moved-to-expectr.md)
  failure messages now give the row count and preview the first rows.
  Messages are shown literally (braces are no longer interpolated). With
  `warn_msg` or `abort_msg` set, the success message defaults to
  `"Check passed: <message>"`, so the log names every check. Failures
  signal class `daos_check_failure` with the rows in `$violations`. Log
  lines now include the row count. New `dump` argument writes offending
  rows to CSV; `log` and `dump` default to the options `daos.check_log`
  and `daos.check_dump`.

- `age(year)` defaults to `primo = "previous_ultimo"`: opening ages on
  31 December of the previous year. Use `primo = "jan1"` for 1 January
  ages.

- [`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
  gains `digits`: keep zero displayed decimals by default, choose a
  different precision, or use `NULL` to disable automatic numeric
  formatting. Stored values are unchanged.

- Consolidate Excel writing in `write_excel(mode = ...)`: `new`
  (default), `append`, `replace` (matching sheets), and `overwrite`
  (entire workbook). Remove `append_excel()` and the former `overwrite`
  argument.

- Excel exports now write numeric missing values as blank cells and
  handle all-missing numeric columns without warnings. Invalid or
  duplicate sheet names and invalid list inputs are rejected before
  writing. `mode = "replace"` matches sheet names ignoring case and
  preserves replaced sheets’ positions.

- Add
  [`inspect_db()`](https://dataniel.github.io/daos/reference/inspect_db.md)
  to diagnose mixed full DB07/DB25 codes, returning key membership and
  both labels. Shared codes remain unresolved, even if labels match;
  unknown and missing codes receive explicit statuses.

- Add
  [`db_label()`](https://dataniel.github.io/daos/reference/db_label.md)
  to look up Danish industry titles from bundled DST tables for DB25 or
  DB07, including hierarchy codes. Requires an explicit `version`.
  Accepts dotted or compact input; unknown codes warn and return `NA`.

- Add
  [`convert_db07_to_db25()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
  and
  [`convert_db25_to_db07()`](https://dataniel.github.io/daos/reference/convert_db07_to_db25.md)
  using bundled DST keys (source page updated 26 February 2026). Both
  accept mixed code formatting and offer dotted or compact output. The
  default strict method warns and returns `NA` for splits;
  `method = "simple"` uses DST’s separate approximate matrix for each
  direction. Invalid or unknown full codes also warn and return `NA`.

- [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  now accepts selections such as `sex`, `bday`, and
  `alder = age(year, "ultimo")`. Multiple age references work in one
  call. This replaces the `add`, `ref_date`, `year`, and `at` arguments.

- `age(year)` uses the previous 31 December; `age(date = ...)` accepts
  an explicit date. Bare `age` uses today. Default output still includes
  all five information types.

- [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  preserves the source CPR column. Use
  [`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
  explicitly to standardise it. Existing output columns require
  `overwrite = TRUE`; duplicate output names and replacing the source
  CPR column are errors.

- CPR cleaning and derivation now share a registered native C kernel.
  Each CPR is parsed once per
  [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  call, including multiple ages; modulus-11 no longer allocates a digit
  matrix. ISO reference dates are validated directly without parsing and
  formatting them through POSIXlt.

- [`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
  returns already standardised character vectors without copying them.
  Cleaning remains optional before
  [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  and is useful when standardising identifiers for joins or export.

- Source installations now require a C compiler (Rtools on Windows).

- Replace the experimental `drop_all_na()` with
  [`drop_empty_rows()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md)
  and
  [`drop_empty_cols()`](https://dataniel.github.io/daos/reference/drop_empty_rows.md).
  Both accept tidyselect column selections, including
  `where(is.numeric)`, plus `blank = TRUE` for empty/whitespace-only
  text.
