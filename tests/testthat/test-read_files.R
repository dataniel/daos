test_that("read_files() reads a single CSV file", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x;y\n1;a\n2;b", f)
  result <- read_files(f)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
})

test_that("read_files() returns a named list for multiple files", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\n2", f2)
  result <- read_files(c(a = f1, b = f2))
  expect_type(result, "list")
  expect_named(result, c("a", "b"))
})

test_that("read_files() uses filenames as names when paths are unnamed", {
  dir  <- withr::local_tempdir()
  path <- file.path(dir, "myfile.csv")
  writeLines("x\n1", path)
  result <- read_files(c(path, path))
  expect_named(result, c("myfile", "myfile"))
})

test_that("read_files() aborts on unsupported extension", {
  expect_error(read_files("data.xyz"), class = "rlang_error")
})
