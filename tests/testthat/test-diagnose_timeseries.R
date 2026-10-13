test_that("diagnostics preserve time gaps, missing values and duplicate dates", {
  d <- data.frame(date = seq(as.Date("2020-01-01"), by = "month", length.out = 48), value = 1:48)
  gap <- diagnose_timeseries(d[-15, ], date, value)
  expect_equal(gap$missing_periods, 1)
  expect_false(gap$regular)
  expect_equal(nrow(gap$decomposition[[1]]), 0)
  expect_equal(nrow(gap$tests[[1]]), 0)
  d$value[c(4, 5)] <- c(NA, Inf)
  d$date[8] <- d$date[7]
  d$date[12] <- NA
  r <- diagnose_timeseries(d, date, value)
  expect_equal(r$n, 48)
  expect_equal(r$n_finite, 46)
  expect_equal(r$missing, 1)
  expect_equal(r$non_finite, 1)
  expect_equal(r$duplicate_times, 1)
  expect_equal(r$missing_time, 1)
  expect_true(any(grepl("No observations were removed", r$notes[[1]])))
})

test_that("calendar frequency handles months, quarters and month ends", {
  monthly <- seq(as.Date("2015-06-01"), by = "month", length.out = 60)
  expect_equal(screen_ts_time_info(monthly)$period, 12)
  quarterly <- seq(as.Date("2010-01-01"), by = "3 months", length.out = 40)
  expect_equal(screen_ts_time_info(quarterly)$period, 4)
  ends <- seq(as.Date("2010-02-01"), by = "month", length.out = 40) - 1
  expect_true(screen_ts_time_info(ends)$regular)
  expect_equal(screen_ts_time_info(ends)$period, 12)
  expect_false(screen_ts_time_info(c(1, 2, 3.25, 4))$regular)
})

test_that("short, constant and empty series have explicit unavailable results", {
  r <- diagnose_timeseries(data.frame(t = 1:5, y = c(1, 2, 4, 3, 5)), t, y)
  expect_equal(nrow(r$tests[[1]]), 0)
  expect_true(any(grepl("20 observations", r$notes[[1]])))
  constant <- diagnose_timeseries(data.frame(t = 1:40, y = 7), t, y)
  expect_equal(constant$n_outliers, 0)
  expect_equal(nrow(constant$correlation[[1]]), 0)
  expect_true(any(grepl("Constant series", constant$notes[[1]])))
  empty <- diagnose_timeseries(data.frame(t = numeric(), y = numeric()), t, y)
  expect_equal(empty$n, 0)
  expect_true(is.na(empty$mean))
  missing <- diagnose_timeseries(data.frame(t = 1:40, y = NA_real_), t, y)
  expect_equal(missing$missing, 40)
  expect_true(is.na(missing$min))
})

test_that("seasonal screening finds a planted spike after decomposition", {
  set.seed(107)
  d <- data.frame(t = seq(as.Date("2000-01-01"), by = "month", length.out = 120),
    y = 20 + seq_len(120) / 10 + rep(8 * sin(2 * pi * (1:12) / 12), 10) + rnorm(120, sd = 0.2))
  d$y[60] <- d$y[60] + 30
  r <- diagnose_timeseries(d, t, y, .features = c("outliers", "seasonality"))
  expect_equal(r$period, 12)
  expect_equal(nrow(r$decomposition[[1]]), 120)
  expect_true(d$t[60] %in% r$outliers[[1]]$time)
  expect_gt(r$seasonal_strength, 0.5)
  expect_equal(nrow(r$tests[[1]]), 0)
  expect_equal(nrow(r$correlation[[1]]), 0)
  expect_equal(r$decomposition[[1]]$observed,
    with(r$decomposition[[1]], trend + seasonal + remainder), tolerance = 1e-8)
})

test_that("tools run independently and grouping produces one result per series", {
  d <- data.frame(t = rep(1:40, 2), group = rep(c("a", "b"), each = 40),
                  y = c(sin(1:40), cos(1:40)))
  summary <- diagnose_timeseries(dplyr::group_by(d, group), t, y, .features = "summary")
  expect_equal(summary$group, c("a", "b"))
  expect_equal(summary$n, c(40, 40))
  expect_true(all(lengths(summary$notes) == 0))
  expect_true(all(vapply(summary$decomposition, nrow, integer(1)) == 0))
  r <- diagnose_timeseries(d[d$group == "a", ], t, y, .features = "autocorrelation")
  expect_gt(nrow(r$correlation[[1]]), 0)
  expect_equal(nrow(r$decomposition[[1]]), 0)
  expect_equal(nrow(r$tests[[1]]), 0)
})

test_that("stationarity tests state their different null hypotheses", {
  skip_if_not_installed("feasts")
  skip_if_not_installed("urca")
  set.seed(4)
  r <- diagnose_timeseries(data.frame(t = 1:100, y = rnorm(100)), t, y,
                          .features = "stationarity")
  expect_equal(nrow(r$tests[[1]]), 2)
  expect_equal(r$tests[[1]]$null_hypothesis, c("Level stationarity", "Unit root"))
  expect_true(all(is.finite(r$tests[[1]]$p_value)))
  expect_equal(nrow(r$decomposition[[1]]), 0)
})

test_that("break searches are bounded and locate a planted level shift", {
  large <- screen_ts_diagnose(1:2001, sin(1:2001), breaks = "level", features = "summary")
  expect_true(is.na(large$n_breaks))
  expect_true(any(grepl("30-2000", large$notes[[1]])))
  skip_if_not_installed("strucchange")
  set.seed(19)
  d <- data.frame(t = 1:120, y = c(rep(0, 60), rep(10, 60)) + rnorm(120, sd = 0.3))
  r <- diagnose_timeseries(d, t, y, .breaks = "level", .features = "summary")
  expect_true(any(abs(r$breakpoints[[1]]$time - 61) <= 2))
  expect_equal(r$n_breaks, nrow(r$breakpoints[[1]]))
  expect_true(all(r$breakpoints[[1]]$lower <= r$breakpoints[[1]]$time))
  expect_true(all(r$breakpoints[[1]]$upper >= r$breakpoints[[1]]$time))
})

test_that("invalid diagnostic inputs are rejected", {
  d <- data.frame(t = 1:20, y = 1:20)
  expect_error(diagnose_timeseries(d, t, y, .period = 0), "positive whole")
  expect_error(diagnose_timeseries(d, t, y, .period = 2.5), "positive whole")
  expect_error(diagnose_timeseries(d, t, y, .features = "unknown"))
  expect_error(diagnose_timeseries(dplyr::group_by(d, t), t, y), "grouping")
})
