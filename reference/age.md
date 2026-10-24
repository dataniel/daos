# Specify an age calculation for CPR information

Use inside
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md)
to choose the reference for an age column. This helper describes a
calculation; it does not calculate an age itself.

## Usage

``` r
age(year, at = "primo", date)
```

## Arguments

- year:

  Numeric whole year(s), directly or as a column/expression in the input
  data. Defaults to 1 January of each year.

- at:

  Point in the year: `"primo"` (1 January), `"medio"` (1 July), or
  `"ultimo"` (31 December). Only allowed with `year`.

- date:

  A Date vector or strict ISO date strings (`YYYY-MM-DD`). Supply either
  `year` or `date`. With neither, uses
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

## Value

An age specification for
[`add_cpr_info()`](https://dataniel.github.io/daos/reference/add_cpr_info.md).

## Details

References may have length one or one value per input row. Missing
references produce missing ages. Data columns take precedence over
caller variables; `.env` and `.data` can make the source explicit.

## Examples

``` r
df <- data.frame(pnr = "0101004007", year = 2025L)
add_cpr_info(df, pnr, age(year), sex)
#>          pnr year age sex
#> 1 0101004007 2025  25   1
add_cpr_info(df, pnr, alder = age(date = "2025-07-01"))
#>          pnr year alder
#> 1 0101004007 2025    25
```
