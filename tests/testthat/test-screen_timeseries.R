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

test_that("group columns named like paste() arguments are ordinary groups", {
  for (nm in c("sep", "collapse", "recycle0")) {
    d <- data.frame(t = rep(1:3, 2), y = 1:6)
    d[[nm]] <- rep(c("a", "b"), each = 3)
    p <- screen_ts_prepare(d, "t", "y", nm)
    expect_equal(nrow(p$keys), 2)
    expect_identical(screen_ts_lookup(p, list("2")), 2L)
  }
})

test_that("tsibble indices reach plotly as dates, overlays included", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("tsibble")
  # getExportedValue(): tsibble is optional here and not worth a Suggests entry.
  yearmonth <- getExportedValue("tsibble", "yearmonth")
  d <- data.frame(y = sin(2 * pi * (1:48) / 12) + c(rep(0, 24), 25, rep(0, 23)))
  d$t <- yearmonth(seq(as.Date("2020-01-01"), by = "month", length.out = 48))
  r <- screen_ts_diagnose(d$t, d$y, 12, features = c("seasonality", "outliers"))
  r$breakpoints[[1]] <- tibble::tibble(time = d$t[10], lower = d$t[9], upper = d$t[11])
  b <- plotly::plotly_build(screen_ts_plot(d, "t", "y", diagnostics = r, breaks = r, seasonality = TRUE))
  expect_gt(length(b$x$data), 1)
  for (trace in b$x$data) expect_s3_class(trace$x, "Date")
  expect_s3_class(b$x$data[[1]]$x, "Date")
  expect_equal(b$x$data[[1]]$x[1], as.Date("2020-01-01"))
  expect_s3_class(b$x$layout$shapes[[1]]$x0, "Date")
  expect_equal(screen_ts_plot_time(1:3), 1:3)
})

test_that("column errors name the problem in the user's terms", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(year = 1:3, gdp = 1:3, label = "a", g = "x")
  expect_error(screen_timeseries(d, yr, gdp), "\"yr\".*`x`.*not found")
  expect_error(screen_timeseries(d, yr, gdp), "Did you mean \"year\"", fixed = FALSE)
  expect_error(screen_timeseries(d, year, zzzzzz), "Available columns.*\"year\"")
  expect_error(screen_timeseries(d, year, gdp, series = lne), "`series`")
  expect_error(screen_timeseries(d, year + 1, gdp), "not the expression `year \\+ 1`")
  expect_error(screen_timeseries(d, y = gdp), "`x` is required")
  expect_error(screen_timeseries(d, year, label), "\"label\" is <character>")
  listy <- d
  listy$items <- list(1, 2, 3)
  expect_error(screen_timeseries(listy, items, gdp), "list column \"items\"")
  expect_error(diagnose_timeseries(d, yr, gdp), "Did you mean \"year\"")
  expect_error(diagnose_timeseries(d, year, label), "\"label\" is <character>")
  # The error points at the function the user called.
  caught <- tryCatch(screen_timeseries(d, yr, gdp), error = identity)
  expect_match(deparse(caught$call)[1], "screen_timeseries", fixed = TRUE)
  # Quoted names keep working, in every position.
  local_mocked_bindings(runApp = function(...) NULL, .package = "shiny")
  expect_output(screen_timeseries(d, "year", "gdp", series = "label"), "No groups")
})

test_that("merged tool results equal a single run with the same tools", {
  y <- sin(2 * pi * (1:60) / 12) + (1:60) / 30
  y[30] <- 25
  tools <- c("autocorrelation", "outliers", "seasonality", "summary")
  whole <- screen_ts_diagnose(1:60, y, 12, "none", tools)
  merged <- screen_ts_merge_diagnostics(lapply(tools, function(tool) {
    screen_ts_diagnose(1:60, y, 12, "none", tool)
  }))
  expect_setequal(merged$notes[[1]], whole$notes[[1]])
  merged$notes <- whole$notes
  expect_equal(merged, whole)
  # Nothing to fill in must leave an unavailable tool unavailable.
  expect_true(is.na(merged$n_breaks))
})

test_that("switching tools repeats no work and redraws only for overlays", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = 1:40, y = sin(1:40), group = "a")
  p <- screen_ts_prepare(d, "t", "y", "group")
  tools_run <- character()
  draws <- 0L
  diagnose <- screen_ts_diagnose
  plot <- screen_ts_plot
  local_mocked_bindings(
    screen_ts_diagnose = function(x, y, period = NULL, breaks = "none", features = character()) {
      tools_run <<- c(tools_run, if (breaks != "none") "breaks" else features)
      diagnose(x, y, period, breaks, features)
    },
    screen_ts_plot = function(...) {
      draws <<- draws + 1L
      plot(...)
    })
  shiny::testServer(screen_ts_server(p, "t", "y"), {
    session$setInputs(diagnostics = "outliers", y_min = NA_real_, y_max = NA_real_)
    output$plot
    expect_equal(draws, 1L)
    session$setInputs(diagnostics = c("outliers", "summary"))
    diagnostics()
    output$plot
    expect_equal(draws, 1L)
    session$setInputs(diagnostics = c("autocorrelation", "outliers", "summary"))
    diagnostics()
    output$plot
    expect_equal(draws, 1L)
    expect_equal(tools_run, c("outliers", "summary", "autocorrelation"))
    # A tool that draws on the plot does redraw it, and keeps the same revision.
    session$setInputs(diagnostics = c("outliers", "seasonality"))
    output$plot
    expect_equal(draws, 2L)
    expect_equal(sum(tools_run == "outliers"), 1L)
    # Turning a tool off and on again uses the cache.
    session$setInputs(diagnostics = "outliers")
    diagnostics()
    session$setInputs(diagnostics = c("outliers", "seasonality"))
    diagnostics()
    expect_equal(sum(tools_run == "seasonality"), 1L)
  })
})

test_that("zoom revision is sent to plotly and left out when not asked for", {
  skip_if_not_installed("plotly")
  d <- data.frame(t = 1:3, y = 1:3)
  kept <- plotly::plotly_build(screen_ts_plot(d, "t", "y", ui_revision = "1"))$x$layout
  expect_equal(kept$uirevision, "1")
  expect_equal(kept$transition$duration, 0)
  plain <- plotly::plotly_build(screen_ts_plot(d, "t", "y"))$x$layout
  expect_null(plain$uirevision)
  expect_null(plain$transition)
})

test_that("a series keeps its colour across groups and time ranges", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  d <- data.frame(t = c(1:3, 1:3, 1:3), y = 1:9, g = rep(c("one", "two"), c(6, 3)),
    line = rep(c("a", "b", "b"), each = 3))
  colour <- function(data, ...) {
    b <- plotly::plotly_build(screen_ts_plot(data, "t", "y", "line", ...))
    stats::setNames(vapply(b$x$data, function(tr) tr$line$color, ""),
      vapply(b$x$data, function(tr) tr$name, ""))
  }
  levels <- unique(d$line)
  both <- colour(d[d$g == "one", ], series_levels = levels)
  only_b <- colour(d[d$g == "two", ], series_levels = levels)
  expect_false(both[["a"]] == both[["b"]])
  expect_identical(only_b[["b"]], both[["b"]])
  # Beyond the palette colours repeat rather than going missing.
  many <- data.frame(t = 1, y = 1, line = letters[1:9])
  expect_identical(colour(many)[["i"]], colour(many)[["a"]])
  # Missing series have a colour too.
  gaps <- data.frame(t = 1:2, y = 1:2, line = c(NA, "a"))
  expect_false(anyNA(colour(gaps)))
  # The app passes the levels for the whole data set.
  p <- screen_ts_prepare(d, "t", "y", "g", "line")
  shiny::testServer(screen_ts_server(p, "t", "y", "line"), {
    session$setInputs(prev = 0, next_btn = 0, diagnostics = character())
    expect_match(output$plot, both[["a"]], fixed = TRUE)
    session$setInputs(next_btn = 1)
    expect_match(output$plot, both[["b"]], fixed = TRUE)
    expect_false(grepl(both[["a"]], output$plot, fixed = TRUE))
  })
})

test_that("the app uses system fonts and loads nothing external", {
  skip_if_not_installed("shiny")
  # as.character() on a head tag is empty, so render its children instead.
  head <- paste(vapply(screen_ts_head()$children, as.character, ""), collapse = "\n")
  expect_match(head, "keydown.screening", fixed = TRUE)
  expect_false(grepl("googleapis|@font-face|<link|https?://", head))
  expect_false(grepl("Inter", screen_ts_font, fixed = TRUE))
  expect_match(head, screen_ts_font, fixed = TRUE)
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
  doubles <- tibble::tibble(k = c(0.1 + 0.2, 1234567.1234567891, 1/3))
  eval(parse(text = screen_ts_result_code(doubles)), envir = env)
  expect_identical(env$flagged, doubles)
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
