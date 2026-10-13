test_that("screen_timeseries() aborts on non-data-frame input", {
  expect_error(screen_timeseries(list(), x = t, y = v), class = "rlang_error")
})

test_that("indexed groups preserve types, NA keys and sorted row identity", {
  d <- data.frame(t = c(3, 1, 2, 2, 1, 3), y = 1:6,
    a = factor(c("x:y", "x:y", NA, "NA", "NA", NA)),
    b = as.Date(c("2020-01-01", "2020-01-01", "2021-01-01", "2020-01-01", "2020-01-01", "2021-01-01")))
  p <- screen_ts_prepare(d, "t", "y", c("a", "b"))
  for (i in seq_len(nrow(p$keys))) {
    expected <- dplyr::semi_join(tibble::as_tibble(d), p$keys[i, ], by = c("a", "b")) |>
      dplyr::arrange(t)
    expect_identical(p$data[p$rows[[i]], ], expected)
    expect_identical(screen_ts_lookup(p, lapply(p$codes, function(v) as.character(v[i]))), i)
  }
  expect_true(is.na(screen_ts_lookup(p, list("999", "999"))))
  expect_true(is.factor(p$keys$a))
  expect_s3_class(p$keys$b, "Date")
  expect_error(screen_ts_prepare(d[FALSE, ], "t", "y", c("a", "b")), "at least one")
})

test_that("server keeps diagnostics off until selected and caches revisits", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = rep(1:40, 2), y = sin(1:80), group = rep(c("a", "b"), each = 40))
  p <- screen_ts_prepare(d, "t", "y", "group")
  calls <- list()
  original <- screen_ts_diagnose
  local_mocked_bindings(screen_ts_diagnose = function(...) {
    args <- list(...)
    calls[[length(calls) + 1L]] <<- args
    original(...)
  })
  shiny::testServer(screen_ts_server(p, "t", "y"), {
    session$setInputs(prev = 0, next_btn = 0, flag_btn = 0, diagnostics = character())
    expect_equal(idx(), 1)
    expect_equal(length(calls), 0)
    session$setInputs(next_btn = 1)
    expect_equal(idx(), 2)
    expect_equal(current_data()$y, d$y[41:80])
    expect_equal(length(calls), 0)
    session$setInputs(diagnostics = "summary")
    expect_equal(diagnostics()$n, 40)
    expect_equal(length(calls), 1)
    session$setInputs(diagnostic_view = "summary")
    diagnostics()
    session$setInputs(diagnostic_view = "overview")
    diagnostics()
    expect_equal(length(calls), 1)
    session$setInputs(flag_btn = 1)
    expect_equal(flagged_keys()$group, "b")
    session$setInputs(prev = 1)
    diagnostics()
    expect_equal(length(calls), 2)
    session$setInputs(next_btn = 2)
    diagnostics()
    expect_equal(length(calls), 2)
    session$setInputs(diagnostics = character())
    session$setInputs(prev = 2)
    expect_equal(length(calls), 2)
    session$setInputs(diagnostics = "autocorrelation")
    expect_gt(nrow(diagnostics()$correlation[[1]]), 0)
    expect_equal(nrow(diagnostics()$tests[[1]]), 0)
    session$setInputs(diagnostics = "seasonality", diagnostic_period = 4)
    expect_equal(diagnostics()$period, 4)
    session$setInputs(diagnostic_period = NA_real_)
    expect_equal(diagnostics()$period, 1)
    session$setInputs(diagnostics = "summary", diagnostic_period = -1)
    expect_equal(diagnostics()$n, 40)
    session$setInputs(y_min = 0, y_max = 20)
    expect_equal(axis_limits(), list(lower = 0, upper = 20))
    session$setInputs(y_min = NA_real_, y_max = NA_real_)
    expect_equal(axis_limits(), list(lower = NULL, upper = NULL))
  })
})

test_that("diagnosis of multiple lines uses only the selected series", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = rep(1:40, 2), y = c(rep(1, 40), rep(10, 40)),
    line = rep(c("a", "b"), each = 40), group = "one")
  p <- screen_ts_prepare(d, "t", "y", "group", "line")
  shiny::testServer(screen_ts_server(p, "t", "y", "line"), {
    session$setInputs(diagnostics = "summary", diagnostic_series = "1")
    expect_equal(output$plot_subtitle, "2 series | 40 observations each")
    expect_equal(diagnostics()$mean, 1)
    session$setInputs(diagnostic_series = "2")
    expect_equal(diagnostics()$mean, 10)
  })
})

test_that("native plots keep data and add only requested diagnostic layers", {
  skip_if_not_installed("plotly")
  d <- data.frame(t = 1:60, y = rep(sin(2 * pi * (1:12) / 12), 5))
  r <- screen_ts_diagnose(d$t, d$y, 12, features = "seasonality")
  basic <- plotly::plotly_build(screen_ts_plot(d, "t", "y"))
  seasonal <- plotly::plotly_build(screen_ts_plot(d, "t", "y", diagnostics = r, seasonality = TRUE))
  expect_equal(length(basic$x$data), 1)
  expect_equal(length(seasonal$x$data), 2)
  expect_equal(as.numeric(basic$x$data[[1]]$y), d$y)
  expect_equal(seasonal$x$data[[2]]$name, "Trend + season")
  expect_equal(screen_ts_yaxis(rep(NA_real_, 3), 0)$range[1], 0)
})

test_that("group selectors and arrows agree, including sparse and missing keys", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = rep(1:5, 3), y = 1:15,
    a = rep(c("x", "y", NA), each = 5), b = rep(c("m", "n", "m"), each = 5))
  p <- screen_ts_prepare(d, "t", "y", c("a", "b"))
  notifications <- character()
  local_mocked_bindings(showNotification = function(ui, ...) {
    notifications <<- c(notifications, ui)
  }, .package = "shiny")
  shiny::testServer(screen_ts_server(p, "t", "y"), {
    session$setInputs(group_1 = "", group_2 = "")
    expect_equal(idx(), 1)
    expect_length(notifications, 0)
    session$setInputs(group_1 = "1", group_2 = "1", next_btn = 0, prev = 0)
    session$setInputs(group_1 = "2", group_2 = "2")
    expect_equal(idx(), 2)
    expect_equal(current_key()$a, "y")
    session$setInputs(group_1 = "2", group_2 = "1")
    expect_equal(idx(), 1)
    expect_equal(current_key()$b, "m")
    session$setInputs(group_1 = "3", group_2 = "1")
    expect_equal(idx(), 3)
    expect_true(is.na(current_key()$a))
    session$setInputs(next_btn = 1)
    expect_equal(idx(), 3)
    session$setInputs(prev = 1)
    expect_equal(idx(), 2)
  })
})

test_that("screen_timeseries() aborts when no grouping columns remain", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  df <- data.frame(year = 2020:2022, value = 1:3)
  expect_error(screen_timeseries(df, x = year, y = value), class = "rlang_error")
})

test_that("pasteable output reconstructs flagged keys including classes and quoting", {
  keys <- tibble::tibble(
    `odd name` = c("a\"b", "line\nbreak", NA_character_),
    factor = factor(c("b", NA, "a"), levels = c("a", "b", "unused")),
    date = as.Date(c("2020-01-01", NA, "2021-01-01")),
    number = c(1L, NA_integer_, 3L), flag = c(TRUE, FALSE, NA))
  env <- new.env(parent = globalenv())
  eval(parse(text = screen_ts_result_code(keys)), envir = env)
  expect_identical(env$flagged, keys)
  eval(parse(text = screen_ts_result_code(NULL)), envir = env)
  expect_null(env$flagged)
})

test_that("closing the session returns flags once", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = 1:3, y = 1:3, group = "a")
  p <- screen_ts_prepare(d, "t", "y", "group")
  stopped <- list()
  local_mocked_bindings(stopApp = function(returnValue = NULL) {
    stopped[[length(stopped) + 1L]] <<- list(value = returnValue)
  }, .package = "shiny")
  shiny::testServer(screen_ts_server(p, "t", "y"), {
    session$setInputs(flag_btn = 0)
    session$setInputs(flag_btn = 1)
    session$close()
    expect_length(stopped, 1)
    expect_identical(stopped[[1]]$value, p$keys)
    finish()
    expect_length(stopped, 1)
  })
})

test_that("console code and invisible return coexist, with an opt-out", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  expected <- tibble::tibble(group = "a")
  local_mocked_bindings(runApp = function(...) expected, .package = "shiny")
  d <- data.frame(t = 1:3, y = 1:3, group = "a")
  printed <- capture.output(value <- withVisible(screen_timeseries(d, t, y)))
  expect_identical(value$value, expected)
  expect_false(value$visible)
  expect_true(any(grepl("flagged <- tibble::tibble", printed, fixed = TRUE)))
  expect_output(screen_timeseries(d, t, y, .print = FALSE), NA)
})
