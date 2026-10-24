# daos (development version)

* `add_cpr_info()` now accepts selections such as `sex`, `bday`, and
  `alder = age(year, "ultimo")`. Multiple age references work in one call.
  This replaces the `add`, `ref_date`, `year`, and `at` arguments.
* `age(year)` uses 1 January; `age(date = ...)` accepts an explicit date.
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
