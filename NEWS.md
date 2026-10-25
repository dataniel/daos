# daos (development version)

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
