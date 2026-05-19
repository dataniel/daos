# Find sign combinations that sum to a target

Given a set of labelled values and a target total, determines which
multipliers (`+1`, `-1`, or `0`) to apply to each value so that the
signed sum equals the target. Uses a *meet-in-the-middle* algorithm for
efficiency.

## Usage

``` r
find_signs(
  df,
  label_col,
  value_col,
  total_label = "total",
  positive = NULL,
  negative = NULL,
  by = NULL,
  max_zeros = 2L
)
```

## Arguments

- df:

  A data frame containing labels and values.

- label_col:

  Column containing item labels (unquoted).

- value_col:

  Column containing numeric values (unquoted).

- total_label:

  Label of the row whose value is the reconciliation target. Default:
  `"total"`.

- positive:

  Character vector of labels that must receive a positive sign.
  Optional.

- negative:

  Character vector of labels that must receive a negative sign.
  Optional.

- by:

  Optional grouping columns (unquoted). When supplied, the
  reconciliation is performed separately for each group.

- max_zeros:

  Maximum number of zero coefficients allowed in a valid solution (i.e.
  how many items can be excluded). Default: `2L`.

## Value

A tibble with the same label/value structure as the input, where values
have been multiplied by their resolved signs. Groups with no unique
solution are silently dropped (`NULL`).

## Details

This is useful for reconciling accounting line items where the sign
convention is unknown — for example, finding which items in a set of
account balances add up to a reported total.

## Examples

``` r
items <- data.frame(
  label = c("revenue", "costs", "depreciation", "total"),
  value = c(100, 40, 10, 50)
)
find_signs(items, label, value, total_label = "total")
#> # A tibble: 0 × 0
```
