# Interactive time-series screening dashboard

Launches a Shiny application for visually reviewing time-series data
group by group. All columns that are not `x`, `y`, `series`, or excluded
become grouping dimensions with dropdown selectors. Navigate between
groups with the arrow keys or the `←` / `→` buttons. Press `Esc` to
exit.

## Usage

``` r
time2screen(data, x, y, series = NULL, .exclude = NULL, .from_zero = FALSE)
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

- .from_zero:

  If `TRUE`, the y-axis starts at zero. Can also be toggled
  interactively via the "Start at zero" button. Default: `FALSE`.

## Value

A Shiny app object. In an interactive session the app is displayed
immediately; otherwise it is launched in a browser.

## Details

Requires the `shiny` and `highcharter` packages.

## Examples

``` r
if (FALSE) { # \dontrun{
library(dplyr)

# Simple example with economics dataset:
ggplot2::economics_long |>
  time2screen(date, value, series = variable)

# With a grouping column:
df <- data.frame(
  year    = rep(2010:2020, 3),
  country = rep(c("DK", "SE", "NO"), each = 11),
  gdp     = rnorm(33, 300, 20)
)
time2screen(df, x = year, y = gdp)
} # }
```
