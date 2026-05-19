test_that("time2screen() aborts on non-data-frame input", {
  expect_error(time2screen(list(), x = t, y = v), class = "rlang_error")
})

test_that("time2screen() aborts when no grouping columns remain", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("highcharter")
  df <- data.frame(year = 2020:2022, value = 1:3)
  expect_error(time2screen(df, x = year, y = value), class = "rlang_error")
})
