test_that("require_files() returns a named character vector for existing files", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  result <- require_files(f)
  expect_type(result, "character")
  expect_named(result)
})

test_that("require_files() aborts when a file is missing", {
  expect_error(
    require_files("/no/such/file.csv"),
    class = "rlang_error"
  )
})

test_that("require_files() expands glue patterns", {
  dir <- withr::local_tempdir()
  paths <- file.path(dir, paste0("dat", 0:2, ".csv"))
  for (p in paths) writeLines("x\n1", p)

  result <- require_files(file.path(dir, "dat{0:2}.csv"))
  expect_length(result, 3)
})

test_that("require_files() uses filenames as names by default", {
  dir  <- withr::local_tempdir()
  path <- file.path(dir, "mydata.csv")
  writeLines("x\n1", path)
  result <- require_files(path)
  expect_equal(names(result), "mydata")
})

test_that("require_files() respects custom .names", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  result <- require_files(f, .names = "custom")
  expect_equal(names(result), "custom")
})
