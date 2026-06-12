skip_if_not_installed("openxlsx2")

tmp <- function() tempfile(fileext = ".xlsx")

test_that("adds a sheet to an existing file", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  append_excel(list(Iris = iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("errors if sheet already exists and overwrite = FALSE", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  expect_error(append_excel(list(Cars = iris), path), "already exists")
})

test_that("replaces sheet when overwrite = TRUE", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  expect_no_error(append_excel(list(Cars = iris), path, overwrite = TRUE))
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Cars")
})

test_that("errors if file does not exist", {
  expect_error(append_excel(list(X = mtcars), tmp()), "does not exist")
})

test_that("single data frame defaults to sheet named Sheet1", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  append_excel(iris, path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Sheet1"))
})

test_that("errors on a non-xlsx path", {
  expect_error(append_excel(mtcars, tempfile(fileext = ".xls")), "xlsx")
})

test_that("returns path invisibly", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  result <- append_excel(list(Iris = iris), path)
  expect_equal(result, path)
})
