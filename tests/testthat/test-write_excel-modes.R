skip_if_not_installed("openxlsx2")

tmp <- function() tempfile(fileext = ".xlsx")

test_that("modes distinguish replacing sheets from replacing the whole file", {
  path <- tmp()
  for (mode in c("append", "replace")) {
    expect_error(write_excel(mtcars, path, mode = mode), "does not exist")
    expect_false(file.exists(path))
  }
  write_excel(list(A = data.frame(x = 1), B = data.frame(x = 2)), path, mode = "overwrite")
  before <- readBin(path, "raw", n = file.info(path)$size)
  expect_error(write_excel(list(C = iris, A = mtcars), path, mode = "append"), "already exists")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_error(write_excel(iris, path, mode = "new"), "already exists")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  write_excel(list(C = data.frame(x = 3)), path, mode = "overwrite")
  expect_equal(openxlsx2::wb_load(path)$sheet_names, "C")
  expect_error(write_excel(iris, tmp(), mode = "invalid"), "'arg'")
  expect_error(write_excel(iris, tmp(), overwrite = TRUE), "unused argument")
})

test_that("replacement preserves sheet order and recognises names ignoring case", {
  path <- tmp()
  write_excel(list(A = data.frame(x = 1), B = data.frame(x = 2)), path)
  expect_error(write_excel(mode = "append", list(a = data.frame(x = 3)), path), "already exists")
  expect_equal(openxlsx2::wb_load(path)$sheet_names, c("A", "B"))
  write_excel(mode = "replace", list(a = data.frame(x = 3), C = data.frame(x = 4)), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("a", "B", "C"))
  expect_equal(openxlsx2::wb_to_df(wb, sheet = "a")$x, 3)
  expect_equal(openxlsx2::wb_to_df(wb, sheet = "B")$x, 2)
  expect_equal(openxlsx2::wb_to_df(wb, sheet = "C")$x, 4)
})

test_that("adds a sheet to an existing file", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  write_excel(mode = "append", list(Iris = iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("errors if sheet already exists and mode is append", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  expect_error(write_excel(mode = "append", list(Cars = iris), path), "already exists")
})

test_that("replaces sheet when mode is replace", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  expect_no_error(write_excel(mode = "replace", list(Cars = iris), path))
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Cars")
})

test_that("errors if file does not exist", {
  expect_error(write_excel(mode = "append", list(X = mtcars), tmp()), "does not exist")
})

test_that("single data frame defaults to sheet named Sheet1", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  write_excel(mode = "append", iris, path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Sheet1"))
})

test_that("errors on a non-xlsx path", {
  expect_error(write_excel(mode = "append", mtcars, tempfile(fileext = ".xls")), "xlsx")
})

test_that("returns path invisibly", {
  path <- tmp()
  write_excel(list(Cars = mtcars), path)
  result <- write_excel(mode = "append", list(Iris = iris), path)
  expect_equal(result, path)
})
