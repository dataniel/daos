# Diagnose time series, optionally within dplyr groups

Computes descriptive statistics, checks the time grid, and screens for
unusual observations after removing trend and (when specified)
seasonality. Regular, complete series also receive autocorrelation
diagnostics and, when `feasts` and `urca` are installed, KPSS and
Phillips-Perron tests.

## Usage

``` r
diagnose_timeseries(
  data,
  x,
  y,
  .period = NULL,
  .breaks = c("none", "level", "trend"),
  .features = c("summary", "outliers", "seasonality", "stationarity", "autocorrelation")
)
```

## Arguments

- data:

  A data frame, optionally grouped with
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).
  Each group must contain one time series.

- x:

  Time column. (Unquoted.)

- y:

  Numeric measurement column. (Unquoted.)

- .period:

  Seasonal period in observations, e.g. `12` for monthly data with
  annual seasonality. `NULL` infers annual seasonality for aligned
  calendar months/quarters; other indices default to `1` (no
  seasonality). This sets seasonality, not the spacing of the time
  index.

- .breaks:

  One of `"none"` (default), `"level"`, or `"trend"`. The latter two
  require `strucchange` and fit up to three breaks with BIC selection on
  seasonally adjusted data. Break searches are limited to 30–2000
  observations and segments of at least 15% of the series (and at least
  10 observations) to bound computational cost.

- .features:

  Diagnostics to compute: any of `"summary"`, `"outliers"`,
  `"seasonality"`, `"stationarity"`, and `"autocorrelation"`. Defaults
  to all of these. Structural breaks are independently enabled by
  `.breaks`.

## Value

A tibble with one row per group (one row for ungrouped input). Scalar
columns describe the series. List columns contain `tests`, `outliers`,
`breakpoints`, `correlation`, `decomposition`, and `notes`. Break dates
denote the first observation in the new segment; their confidence limits
use the same convention. Unavailable diagnostics are empty tables with
an explanation in `notes`. `n_breaks` is `NA` when break detection is
unavailable or not requested, and zero when the fitted model selects no
break dates.

## Details

Missing/non-finite observations, duplicate times and irregular or gapped
indices are reported without deleting or interpolating observations.
They prevent time-dependent diagnostics. Grid inference cannot identify
periods absent throughout the data; inspect the inferred interval.

Outliers are candidates with an absolute robust residual score above
4.5, using robust STL for seasonal series and a running median
otherwise. A zero MAD uses a numerical tolerance and is reported in
`notes`. At least eight observations are required for residual
screening, and seasonal decomposition needs more than two complete
seasons. Unit root tests require at least 20 nonconstant observations
and run on observed values: KPSS has level stationarity as its null;
Phillips-Perron has a unit root as its null. Failure to reject is not
proof of either null. These are exploratory diagnostics, not automatic
data corrections.

## Examples

``` r
d <- data.frame(year = 2001:2040, value = sin(1:40) + (1:40) / 10)
diagnose_timeseries(d, year, value)
#> # A tibble: 1 × 32
#>       n n_finite missing non_finite missing_time duplicate_times start end  
#>   <int>    <int>   <int>      <int>        <int>           <int> <chr> <chr>
#> 1    40       40       0          0            0               0 2001  2040 
#> # ℹ 24 more variables: interval <chr>, regular <lgl>, missing_periods <dbl>,
#> #   period <int>, mean <dbl>, median <dbl>, sd <dbl>, min <dbl>, q25 <dbl>,
#> #   q75 <dbl>, max <dbl>, last <dbl>, change <dbl>, change_pct <dbl>,
#> #   trend_strength <dbl>, seasonal_strength <dbl>, n_outliers <int>,
#> #   n_breaks <int>, tests <list>, outliers <list>, breakpoints <list>,
#> #   correlation <list>, decomposition <list>, notes <list>
if (FALSE) { # \dontrun{
data |>
  dplyr::group_by(country, variable) |>
  diagnose_timeseries(date, value, .period = 12)
} # }
```
