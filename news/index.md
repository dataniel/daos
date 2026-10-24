# Changelog

## daos (development version)

- [`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
  now accepts selections such as `sex`, `bday`, and
  `alder = age(year, "ultimo")`. Multiple age references work in one
  call. This replaces the `add`, `ref_date`, `year`, and `at` arguments.

- `age(year)` uses 1 January; `age(date = ...)` accepts an explicit
  date. Bare `age` uses today. Default output still includes all five
  information types.

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
