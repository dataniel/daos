skip_if_not_installed("openxlsx2")

tmp <- function() tempfile(fileext = ".xlsx")

test_that("creates a new file from a single data frame", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_true(file.exists(path))
})

test_that("single df defaults to sheet named Sheet1", {
  path <- tmp()
  write_excel(mtcars, path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Sheet1")
})

test_that("named list produces correct sheet names", {
  path <- tmp()
  write_excel(list(Cars = mtcars, Iris = iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("unnamed list gets default sheet names", {
  path <- tmp()
  write_excel(list(mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Sheet1", "Sheet2"))
})

test_that("mixed named/unnamed list uses name where given", {
  path <- tmp()
  write_excel(list(Hoved = mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Hoved", "Sheet2"))
})

test_that("errors if file exists and overwrite = FALSE", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_error(write_excel(mtcars, path), "already exists")
})

test_that("overwrites file when overwrite = TRUE", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_no_error(write_excel(mtcars, path, overwrite = TRUE))
})

test_that("errors on a non-xlsx path", {
  expect_error(write_excel(mtcars, tempfile(fileext = ".xls")), "xlsx")
  expect_error(write_excel(mtcars, tempfile(fileext = ".csv")), "xlsx")
})

test_that("returns path invisibly", {
  path <- tmp()
  result <- write_excel(mtcars, path)
  expect_equal(result, path)
})

test_that(".xl_is_yearlike() detects year columns", {
  expect_true(daos:::.xl_is_yearlike(c(2019, 2020, 2021)))
  expect_true(daos:::.xl_is_yearlike(c(1995L, NA, 2024L)))
  expect_false(daos:::.xl_is_yearlike(c(2020, 12345)))     # outside range
  expect_false(daos:::.xl_is_yearlike(c(2020.5, 2021)))    # not whole numbers
  expect_false(daos:::.xl_is_yearlike(c(NA_real_, NA_real_)))
})

test_that("year-like columns are excluded from the number format", {
  df <- data.frame(year = c(2019, 2020), amount = c(1234567, 2345678))
  path <- tmp()
  write_excel(df, path)
  wb <- openxlsx2::wb_load(path)
  styled_dims <- wb$worksheets[[1]]$sheet_data$cc
  # amount cells carry a style, year cells do not
  amount_styles <- styled_dims$c_s[styled_dims$c_r == "B" & styled_dims$row_r != "1"]
  year_styles   <- styled_dims$c_s[styled_dims$c_r == "A" & styled_dims$row_r != "1"]
  expect_true(all(amount_styles != ""))
  expect_true(all(year_styles == "" | is.na(year_styles)))
})

test_that("detect_years = FALSE formats year columns again", {
  df <- data.frame(year = c(2019, 2020), amount = c(1234567, 2345678))
  path <- tmp()
  write_excel(df, path, detect_years = FALSE)
  wb <- openxlsx2::wb_load(path)
  styled_dims <- wb$worksheets[[1]]$sheet_data$cc
  year_styles <- styled_dims$c_s[styled_dims$c_r == "A" & styled_dims$row_r != "1"]
  expect_true(all(year_styles != ""))
})
