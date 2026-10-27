# Count violations for several rules at once

Evaluates a set of named rules and returns one row per rule with the
number of violating rows. Where a chain of
[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)
calls stops at the first abort, `tally_violations()` evaluates every
rule, so a delivery with five problems is reported as five problems in
one go.

## Usage

``` r
tally_violations(data, ...)
```

## Arguments

- data:

  A data frame or tibble.

- ...:

  Rules that describe a violating row. Name them; an unnamed rule is
  named after its expression.

## Value

A tibble with one row per rule and the columns `rule` (name), `n`
(number of violating rows) and `rows` (list of their row numbers in
`data`, for `data[rows[[i]], ]`).

## Details

### Why "tally"

To tally is to keep count, as with tally marks or
[`dplyr::tally()`](https://dplyr.tidyverse.org/reference/count.html).
The name marks the difference from the `expect_*()` family: those
*judge* (a check passes, warns or aborts), while `tally_violations()`
only *counts* and never warns or stops. Severity stays a separate,
explicit decision, made afterwards by piping the tally into
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md).
The same tally therefore serves both as a hard gate in production and as
a report you read or send on.

The result is itself a violation set once filtered, which closes the
loop back to
[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md):

    df |>
      tally_violations(
        "Missing id"       = is.na(id),
        "Negative amount"  = amount < 0,
        "Unknown industry" = !branche %in% codebook$branche
      ) |>
      dplyr::filter(n > 0) |>
      expect_empty(abort_msg = "The delivery failed validation")

Kept unfiltered, it is a validation report: send it back to whoever made
the data, e.g. with
[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
after dropping the `rows` column.

Rules follow
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
semantics: each must give `TRUE` for a violating row, and `NA` counts as
no violation. Rules are evaluated with
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html),
so [`if_any()`](https://dplyr.tidyverse.org/reference/across.html),
[`across()`](https://dplyr.tidyverse.org/reference/across.html) and
grouped data work.

## See also

[`expect_empty()`](https://dataniel.github.io/daos/reference/expect_empty.md),
[`expect_none()`](https://dataniel.github.io/daos/reference/expect_none.md)

## Examples

``` r
tally_violations(ggplot2::mpg,
  "Few cylinders"  = cyl < 4,
  "High mileage"   = hwy > 40,
  "Missing model"  = is.na(model)
)
#> # A tibble: 3 × 3
#>   rule              n rows     
#>   <chr>         <int> <list>   
#> 1 Few cylinders     0 <int [0]>
#> 2 High mileage      3 <int [3]>
#> 3 Missing model     0 <int [0]>
```
