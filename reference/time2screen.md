# Interactive time-series screening dashboard

Launches a Shiny application for visually reviewing time-series data
group by group. All columns that are not `x`, `y`, `series`, or excluded
become grouping dimensions with dropdown selectors. Navigate between
groups with the arrow keys. Press `Space` to flag the current
combination, `R` to reset zoom, and `Q` to quit.

## Usage

``` r
time2screen(
  data,
  x,
  y,
  series = NULL,
  .exclude = NULL,
  .title = NULL,
  .y_min = NULL,
  .y_max = NULL
)
```

## Arguments

- data:

  A data frame containing at minimum an x-axis column, a y-axis column,
  and at least one grouping column.

- x:

  Time (x-axis) variable. Accepts `Date`, `POSIXct`, numeric years, or
  any value coercible to a date. (Unquoted.)

- y:

  Numeric measurement (y-axis) variable. (Unquoted.)

- series:

  Optional variable for plotting multiple lines per group (e.g. a
  category). (Unquoted.)

- .exclude:

  Columns to exclude from becoming grouping dropdowns. (Unquoted,
  tidy-select.)

- .title:

  Optional title string shown in the app header and in downloaded
  figures. The group combination (`a · b · c`) is always shown
  separately and is not affected.

- .y_min:

  Optional numeric. Pre-fills the Y min input, fixing the lower bound of
  the y-axis globally across all groups. Leave `NULL` for automatic
  scaling. Set to `0` to replicate the old "start at zero" behaviour.

- .y_max:

  Optional numeric. Pre-fills the Y max input, fixing the upper bound of
  the y-axis globally across all groups. Leave `NULL` for automatic
  scaling.

## Value

A data frame of flagged group combinations (the key columns only), or
`NULL` if nothing was flagged. Returned invisibly when the app exits.

## Details

Requires the `shiny` and `highcharter` packages.

## Examples

``` r
if (FALSE) { # \dontrun{
library(dplyr)

# Simple example with economics dataset:
flagged <- ggplot2::economics_long |>
  time2screen(date, value, series = variable)

# With a grouping column:
df <- data.frame(
  year    = rep(2010:2020, 3),
  country = rep(c("DK", "SE", "NO"), each = 11),
  gdp     = rnorm(33, 300, 20)
)
flagged <- time2screen(df, x = year, y = gdp)
} # }
```
