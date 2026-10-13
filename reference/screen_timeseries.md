# Interactive time-series screening dashboard

Launches a Shiny application for visually reviewing time-series data
group by group. All columns that are not `x`, `y`, `series`, or excluded
become grouping dimensions with dropdown selectors. Navigate between
groups with the arrow keys. Press `Space` to flag the current
combination, `R` to reset zoom, and `Q` to quit. Keys `1` to `6` toggle
the diagnostic tools in the order shown; shortcuts are displayed beside
their controls.

## Usage

``` r
screen_timeseries(
  data,
  x,
  y,
  series = NULL,
  .exclude = NULL,
  .title = NULL,
  .y_min = NULL,
  .y_max = NULL,
  .period = NULL,
  .print = TRUE
)
```

## Arguments

- data:

  A data frame containing at minimum an x-axis column, a y-axis column,
  and at least one grouping column.

- x:

  Time (x-axis) variable. Accepts `Date`, `POSIXct`, numeric years, or
  calendar indices such as
  [`tsibble::yearmonth`](https://tsibble.tidyverts.org/reference/year-month.html).
  (Unquoted.)

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
  figures. The group combination (`a | b | c`) is always shown
  separately and is not affected.

- .y_min:

  Optional numeric. Pre-fills the Y min input, fixing the lower bound of
  the y-axis globally across all groups. Leave `NULL` for automatic
  scaling. Set to `0` to replicate the old "start at zero" behaviour.

- .y_max:

  Optional numeric. Pre-fills the Y max input, fixing the upper bound of
  the y-axis globally across all groups. Leave `NULL` for automatic
  scaling.

- .period:

  Optional seasonal period in observations. Pre-fills the app's
  seasonal-period control; `NULL` infers annual seasonality for calendar
  months/quarters and otherwise uses `1`. Can be changed in the app. See
  [`diagnose_timeseries()`](https://dataniel.github.io/daos/reference/diagnose_timeseries.md)
  for methods, requirements and limitations.

- .print:

  Print pasteable R code for the flagged groups on exit. Defaults to
  `TRUE`; set `FALSE` when only the invisible return is wanted. Printing
  also occurs when the function's return value is assigned.

## Value

A data frame of flagged group combinations (the key columns only), or
`NULL` if nothing was flagged. Returned invisibly when the app exits.
Press `Q`, click Finish, or close the browser session to finish. When
`.print = TRUE`, the console also receives a
`flagged <- tibble::tibble(...)` expression preserving the grouping
columns' types. Closing or reloading the browser session ends this local
screening app.

## Details

Requires the `shiny` and `plotly` packages. Diagnostic tools are
selected inside the app and all start switched off. Selected tools
follow the current group; results are cached within the session. With
multiple lines, choose which series to diagnose. Seasonality adds a
trend-plus-season layer and a seasonal profile; outliers and break dates
overlay the main plot. Tools live in the side panel. An integrated panel
below the plot shows findings and results one analysis at a time. Review
scope filters select grouping values and a time range; navigation and
diagnostics use that scope. Existing flags are retained, and returned
flags still identify whole group combinations. The full time range
retains missing times; a narrowed range excludes them.

## Examples

``` r
if (FALSE) { # \dontrun{
library(dplyr)

# Simple example with economics dataset:
flagged <- ggplot2::economics_long |>
  dplyr::mutate(group = "Economics") |>
  screen_timeseries(date, value, series = variable, .exclude = value01)

# With a grouping column:
df <- data.frame(
  year    = rep(2010:2020, 3),
  country = rep(c("DK", "SE", "NO"), each = 11),
  gdp     = rnorm(33, 300, 20)
)
flagged <- screen_timeseries(df, x = year, y = gdp)
} # }
```
