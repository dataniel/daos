skip_if_not_installed("openxlsx2")

tmp <- function() tempfile(fileext = ".xlsx")

test_that("creates a new file from a single data frame", {
  path <- tmp()
  write_pretty_xlsx(mtcars, path)
  expect_true(file.exists(path))
})

test_that("single df defaults to sheet named Sheet1", {
  path <- tmp()
  write_pretty_xlsx(mtcars, path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Sheet1")
})

test_that("named list produces correct sheet names", {
  path <- tmp()
  write_pretty_xlsx(list(Cars = mtcars, Iris = iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("unnamed list gets default sheet names", {
  path <- tmp()
  write_pretty_xlsx(list(mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Sheet1", "Sheet2"))
})

test_that("mixed named/unnamed list uses name where given", {
  path <- tmp()
  write_pretty_xlsx(list(Hoved = mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Hoved", "Sheet2"))
})

test_that("errors if file exists and overwrite = FALSE", {
  path <- tmp()
  write_pretty_xlsx(mtcars, path)
  expect_error(write_pretty_xlsx(mtcars, path), "already exists")
})

test_that("overwrites file when overwrite = TRUE", {
  path <- tmp()
  write_pretty_xlsx(mtcars, path)
  expect_no_error(write_pretty_xlsx(mtcars, path, overwrite = TRUE))
})

test_that("append adds sheet to existing file", {
  path <- tmp()
  write_pretty_xlsx(list(Cars = mtcars), path)
  write_pretty_xlsx(append = list(Iris = iris), path = path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("append errors if sheet already exists and overwrite = FALSE", {
  path <- tmp()
  write_pretty_xlsx(list(Cars = mtcars), path)
  expect_error(
    write_pretty_xlsx(append = list(Cars = iris), path = path),
    "already exists"
  )
})

test_that("append replaces sheet when overwrite = TRUE", {
  path <- tmp()
  write_pretty_xlsx(list(Cars = mtcars), path)
  expect_no_error(
    write_pretty_xlsx(append = list(Cars = iris), path = path, overwrite = TRUE)
  )
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Cars")
})

test_that("append errors if file does not exist", {
  expect_error(
    write_pretty_xlsx(append = list(X = mtcars), path = tmp()),
    "does not exist"
  )
})

test_that("errors if neither data nor append is provided", {
  expect_error(write_pretty_xlsx(path = tmp()), "must be provided")
})

test_that("returns path invisibly", {
  path <- tmp()
  result <- write_pretty_xlsx(mtcars, path)
  expect_equal(result, path)
})
