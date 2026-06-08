test_that("screen_timeseries() aborts on non-data-frame input", {
  expect_error(screen_timeseries(list(), x = t, y = v), class = "rlang_error")
})

test_that("screen_timeseries() aborts when no grouping columns remain", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("plotly")
  df <- data.frame(year = 2020:2022, value = 1:3)
  expect_error(screen_timeseries(df, x = year, y = value), class = "rlang_error")
})
