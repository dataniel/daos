#' Diagnose time series, optionally within dplyr groups
#'
#' Computes descriptive statistics, checks the time grid, and screens for
#' unusual observations after removing trend and (when specified) seasonality.
#' Regular, complete series also receive autocorrelation diagnostics and,
#' when `feasts` and `urca` are installed, KPSS and Phillips-Perron tests.
#'
#' @param data A data frame, optionally grouped with [dplyr::group_by()].
#'   Each group must contain one time series.
#' @param x Time column. (Unquoted.)
#' @param y Numeric measurement column. (Unquoted.)
#' @param .period Seasonal period in observations, e.g. `12` for monthly data
#'   with annual seasonality. `NULL` infers annual seasonality for aligned
#'   calendar months/quarters; other indices default to `1` (no seasonality).
#'   This sets seasonality, not the spacing of the time index.
#' @param .breaks One of `"none"` (default), `"level"`, or `"trend"`.
#'   The latter two require `strucchange` and fit up to three breaks with BIC
#'   selection on seasonally adjusted data. Break searches are limited to
#'   30--2000 observations and segments of at least 15% of the series (and
#'   at least 10 observations) to bound computational cost.
#' @param .features Diagnostics to compute: any of `"summary"`, `"outliers"`,
#'   `"seasonality"`, `"stationarity"`, and `"autocorrelation"`. Defaults to
#'   all of these. Structural breaks are independently enabled by `.breaks`.
#'
#' @details
#' Missing/non-finite observations, duplicate times and irregular or gapped
#' indices are reported without deleting or interpolating observations.
#' They prevent time-dependent diagnostics. Grid inference cannot identify
#' periods absent throughout the data; inspect the inferred interval.
#'
#' Outliers are candidates with an absolute robust residual score above 4.5,
#' using robust STL for seasonal series and a running median otherwise.
#' A zero MAD uses a numerical tolerance and is reported in `notes`.
#' At least eight observations are required for residual screening, and
#' seasonal decomposition needs more than two complete seasons.
#' Unit root tests require at least 20 nonconstant observations and run on
#' observed values: KPSS has level stationarity as its null; Phillips-Perron
#' has a unit root as its null. Failure to reject is not proof of either null.
#' These are exploratory diagnostics, not automatic data corrections.
#'
#' @return A tibble with one row per group (one row for ungrouped input).
#'   Scalar columns describe the series. List columns contain `tests`,
#'   `outliers`, `breakpoints`, `correlation`, `decomposition`, and `notes`.
#'   Break dates denote the first observation in the new segment; their
#'   confidence limits use the same convention. Unavailable diagnostics are
#'   empty tables with an explanation in `notes`.
#'   `n_breaks` is `NA` when break detection is unavailable or not requested,
#'   and zero when the fitted model selects no break dates.
#'
#' @examples
#' d <- data.frame(year = 2001:2040, value = sin(1:40) + (1:40) / 10)
#' diagnose_timeseries(d, year, value)
#' \dontrun{
#' data |>
#'   dplyr::group_by(country, variable) |>
#'   diagnose_timeseries(date, value, .period = 12)
#' }
#' @export
diagnose_timeseries <- function(data, x, y, .period = NULL,
                               .breaks = c("none", "level", "trend"),
                               .features = c("summary", "outliers", "seasonality",
                                             "stationarity", "autocorrelation")) {
  if (!is.data.frame(data)) cli::cli_abort("{.arg data} must be a data frame.")
  x <- rlang::as_name(rlang::enquo(x))
  y <- rlang::as_name(rlang::enquo(y))
  if (!all(c(x, y) %in% names(data))) cli::cli_abort("Unknown time-series column.")
  if (!is.numeric(data[[y]])) cli::cli_abort("{.arg y} must be numeric.")
  screen_ts_validate_period(.period)
  .breaks <- match.arg(.breaks)
  if (length(.features)) .features <- match.arg(.features,
    c("summary", "outliers", "seasonality", "stationarity", "autocorrelation"), several.ok = TRUE)
  if (dplyr::is_grouped_df(data)) {
    if (any(c(x, y) %in% dplyr::group_vars(data))) {
      cli::cli_abort("{.arg x} and {.arg y} must not be grouping columns.")
    }
    return(dplyr::group_modify(data, function(.x, .y) {
      screen_ts_diagnose(.x[[x]], .x[[y]], .period, .breaks, .features)
    }) |> dplyr::ungroup())
  }
  screen_ts_diagnose(data[[x]], data[[y]], .period, .breaks, .features)
}

screen_ts_diagnose <- function(x, y, period = NULL, breaks = "none",
                               features = c("summary", "outliers", "seasonality",
                                            "stationarity", "autocorrelation")) {
  screen_ts_validate_period(period)
  if (length(x) != length(y) || is.list(x)) cli::cli_abort("Invalid time index.")
  o <- order(x, na.last = TRUE)
  x <- x[o]
  y <- y[o]
  finite <- y[is.finite(y)]
  n <- length(y)
  info <- screen_ts_time_info(x)
  period <- if (is.null(period)) info$period else period
  notes <- character()
  attempt <- function(expr, label) {
    tryCatch(withCallingHandlers(expr, warning = function(w) {
      notes <<- c(notes, paste0(label, ": ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }), error = function(e) {
      notes <<- c(notes, paste0(label, ": ", conditionMessage(e)))
      NULL
    })
  }
  safe <- function(f) if (length(finite)) f(finite) else NA_real_
  difference <- if (n >= 2 && all(is.finite(utils::tail(y, 2)))) y[n] - y[n - 1] else NA_real_
  percentage <- if (n >= 2 && is.finite(difference) && y[n - 1] != 0) {
    100 * difference / abs(y[n - 1])
  } else NA_real_
  tests <- tibble::tibble(test = character(), statistic = double(),
    p_value = double(), null_hypothesis = character(), interpretation = character())
  outliers <- tibble::tibble(time = x[FALSE], value = double(), score = double())
  breakpoints <- tibble::tibble(time = x[FALSE], lower = x[FALSE], upper = x[FALSE])
  correlation <- tibble::tibble(lag = integer(), acf = double(), pacf = double())
  decomposition <- tibble::tibble(time = x[FALSE], observed = double(),
    trend = double(), seasonal = double(), remainder = double())
  result <- tibble::tibble(
    n = n, n_finite = length(finite), missing = sum(is.na(y)),
    non_finite = sum(!is.finite(y) & !is.na(y)), missing_time = sum(is.na(x)),
    duplicate_times = sum(duplicated(x[!is.na(x)])),
    start = if (any(!is.na(x))) as.character(x[which(!is.na(x))[1]]) else NA_character_,
    end = if (any(!is.na(x))) as.character(utils::tail(x[!is.na(x)], 1)) else NA_character_,
    interval = info$interval, regular = info$regular, missing_periods = info$gaps,
    period = period, mean = safe(mean), median = safe(stats::median),
    sd = if (length(finite) > 1) stats::sd(finite) else NA_real_,
    min = safe(min), q25 = safe(function(z) unname(stats::quantile(z, 0.25))),
    q75 = safe(function(z) unname(stats::quantile(z, 0.75))), max = safe(max),
    last = if (n && is.finite(y[n])) y[n] else NA_real_,
    change = difference, change_pct = percentage,
    trend_strength = NA_real_, seasonal_strength = NA_real_,
    n_outliers = NA_integer_, n_breaks = NA_integer_)

  usable <- info$regular && all(is.finite(y)) && !anyNA(x) && !anyDuplicated(x)
  constant <- length(finite) > 0 && length(unique(finite)) == 1L
  time_features <- any(features != "summary") || breaks != "none"
  if (!time_features) {
    # Descriptive statistics do not need a regular or complete time index.
  } else if (!usable) {
    notes <- c(notes, paste("Time-dependent diagnostics unavailable: need a regular,",
      "complete index with unique times and finite measurements. No observations were removed."))
  } else if (constant) {
    if ("outliers" %in% features) result$n_outliers <- 0L
    notes <- c(notes, "Constant series: stationarity tests and correlations are undefined.")
  } else {
    if ("autocorrelation" %in% features && n >= 3L) {
      lag_max <- min(36L, floor(n / 4))
      a <- attempt(stats::acf(y, lag.max = lag_max, plot = FALSE), "ACF")
      p <- attempt(stats::pacf(y, lag.max = lag_max, plot = FALSE), "PACF")
      if (!is.null(a) && !is.null(p)) correlation <- tibble::tibble(
        lag = 0:lag_max, acf = as.numeric(a$acf), pacf = c(NA_real_, as.numeric(p$acf)))
    }
    decompose <- any(c("outliers", "seasonality") %in% features) ||
      (breaks != "none" && period > 1)
    if (!decompose) {
      # No residual/decomposition work unless a selected tool needs it.
    } else if (n < 8L) {
      notes <- c(notes, "Residual screening requires at least 8 observations.")
    } else if (period > 1 && n <= 2 * period) {
      notes <- c(notes, "Seasonal decomposition requires more than two complete seasons.")
    } else {
      if (period > 1) {
        fit <- attempt(stats::stl(stats::ts(y, frequency = period),
          s.window = "periodic", robust = TRUE), "STL")
        if (!is.null(fit)) decomposition <- tibble::tibble(time = x, observed = y,
          trend = as.numeric(fit$time.series[, "trend"]),
          seasonal = as.numeric(fit$time.series[, "seasonal"]),
          remainder = as.numeric(fit$time.series[, "remainder"]))
      } else {
        k <- min(21L, if (n %% 2L) n else n - 1L)
        trend <- stats::runmed(y, k = k, endrule = "median")
        decomposition <- tibble::tibble(time = x, observed = y, trend = trend,
          seasonal = rep(0, n), remainder = y - trend)
      }
      if (nrow(decomposition)) {
        residual <- decomposition$remainder
        tolerance <- max(1, max(abs(y))) * 1e-8
        if ("outliers" %in% features) {
          centered <- residual - stats::median(residual)
          scale <- stats::mad(residual)
          if (scale <= tolerance) {
            notes <- c(notes, "Residual MAD is zero or negligible; outlier candidates use a numerical tolerance.")
            candidates <- abs(centered) > tolerance
            score <- rep(NA_real_, n)
          } else {
            score <- centered / scale
            candidates <- abs(score) > 4.5
          }
          outliers <- tibble::tibble(time = x[candidates], value = y[candidates], score = score[candidates])
          result$n_outliers <- nrow(outliers)
        }
        strength <- function(z) {
          v <- stats::var(z)
          if (v > tolerance^2) max(0, min(1, 1 - stats::var(residual) / v)) else NA_real_
        }
        result$trend_strength <- strength(y - decomposition$seasonal)
        result$seasonal_strength <- if (period > 1) strength(y - decomposition$trend) else NA_real_
      }
    }
    if (!"stationarity" %in% features) {
      # Optional packages are not even loaded until the test is selected.
    } else if (n < 20L) {
      notes <- c(notes, "Unit root tests require at least 20 observations.")
    } else if (!requireNamespace("feasts", quietly = TRUE) || !requireNamespace("urca", quietly = TRUE)) {
      notes <- c(notes, "Install packages 'feasts' and 'urca' for KPSS and Phillips-Perron tests.")
    } else {
      kpss <- attempt(feasts::unitroot_kpss(y, type = "mu", lags = "short"), "KPSS")
      pp <- attempt(feasts::unitroot_pp(y, model = "constant", lags = "short"), "Phillips-Perron")
      if (!is.null(kpss) && all(is.finite(kpss))) tests <- dplyr::bind_rows(tests,
        tibble::tibble(test = "KPSS (observed values)", statistic = unname(kpss[[1]]),
          p_value = unname(kpss[[2]]), null_hypothesis = "Level stationarity",
          interpretation = if (kpss[[2]] < 0.05) "Evidence against level stationarity" else "Level stationarity not rejected"))
      if (!is.null(pp) && all(is.finite(pp))) tests <- dplyr::bind_rows(tests,
        tibble::tibble(test = "Phillips-Perron (observed values)", statistic = unname(pp[[1]]),
          p_value = unname(pp[[2]]), null_hypothesis = "Unit root",
          interpretation = if (pp[[2]] < 0.05) "Evidence against a unit root" else "Unit root not rejected"))
      notes <- c(notes, "Unit root tests are exploratory (5% threshold); p-values can be bounded by tabulated critical values. Non-rejection is not proof.")
    }
  }

  if (breaks != "none") {
    if (!usable || constant) {
      notes <- c(notes, "Break detection requires a complete, regular, nonconstant series.")
    } else if (n < 30 || n > 2000) {
      notes <- c(notes, "Break detection is limited to 30-2000 observations to bound computation.")
    } else if (period > 1 && !nrow(decomposition)) {
      notes <- c(notes, "Break detection unavailable without the requested seasonal adjustment.")
    } else if (!requireNamespace("strucchange", quietly = TRUE)) {
      notes <- c(notes, "Install package 'strucchange' for structural break detection.")
    } else {
      response <- if (nrow(decomposition)) y - decomposition$seasonal else y
      frame <- data.frame(value = response, time = seq_len(n))
      formula <- if (breaks == "level") value ~ 1 else value ~ time
      h <- max(10L, ceiling(0.15 * n))
      fit <- attempt(strucchange::breakpoints(formula, data = frame, h = h,
        breaks = min(3L, floor(n / h) - 1L)), "Structural breaks")
      if (!is.null(fit)) {
        chosen <- strucchange::breakpoints(fit)$breakpoints
        chosen <- chosen[!is.na(chosen)]
        result$n_breaks <- length(chosen)
        if (length(chosen)) {
          ci <- attempt(stats::confint(fit, breaks = length(chosen)), "Break confidence intervals")
          lower <- upper <- rep(NA_integer_, length(chosen))
          if (!is.null(ci)) {
            lower <- pmax(1L, pmin(n, ci$confint[, 1] + 1L))
            upper <- pmax(1L, pmin(n, ci$confint[, 3] + 1L))
          }
          breakpoints <- tibble::tibble(time = x[chosen + 1L], lower = x[lower], upper = x[upper])
        }
        notes <- c(notes, paste0("BIC selected ", length(chosen), " ", breaks,
          " break(s), after seasonal adjustment where applicable. Dates are candidates, conditional on this model; serial dependence can affect inference."))
      }
    }
  }
  result$tests <- list(tests)
  result$outliers <- list(outliers)
  result$breakpoints <- list(breakpoints)
  result$correlation <- list(correlation)
  result$decomposition <- list(decomposition)
  result$notes <- list(unique(notes))
  result
}
