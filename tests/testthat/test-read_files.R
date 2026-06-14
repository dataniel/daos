test_that("read_files() reads a single CSV file and returns the object directly", {
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

test_that("read_files() uses filenames as names by default", {
  dir  <- withr::local_tempdir()
  path <- file.path(dir, "myfile.csv")
  writeLines("x\n1", path)
  result <- read_files(c(path, path))
  expect_named(result, c("myfile", "myfile"))
})

test_that("read_files() expands glue patterns", {
  dir <- withr::local_tempdir()
  for (i in 0:2) writeLines("x\n1", file.path(dir, paste0("dat", i, ".csv")))
  result <- read_files(file.path(dir, "dat{0:2}.csv"))
  expect_type(result, "list")
  expect_length(result, 3)
})

test_that("read_files() assigns numeric names as character", {
  dir <- withr::local_tempdir()
  for (i in 1:3) writeLines("x\n1", file.path(dir, paste0("f", i, ".csv")))
  result <- read_files(file.path(dir, "f{1:3}.csv"), names = 1:3)
  expect_named(result, c("1", "2", "3"))
})

test_that("read_files() aborts when a file is missing", {
  expect_error(read_files("/no/such/file.csv"), class = "rlang_error")
})

test_that("read_files() aborts when names length does not match", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  expect_error(read_files(f, names = c("a", "b")), class = "rlang_error")
})

test_that("read_files() aborts on unsupported extension", {
  f <- withr::local_tempfile(fileext = ".xyz")
  writeLines("data", f)
  expect_error(read_files(f), class = "rlang_error")
})

test_that("read_files() aborts on invalid reader", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  expect_error(read_files(f, reader = "myreader"), class = "rlang_error")
})

test_that("read_files() aborts on invalid out", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  expect_error(read_files(f, out = "merge"), class = "rlang_error")
})

test_that("read_files() uses a custom reader function", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x,y\n1,a", f)
  result <- read_files(f, reader = \(path) readr::read_csv(path, show_col_types = FALSE))
  expect_equal(result$x, 1)
  expect_equal(result$y, "a")
})

test_that("read_files(out = 'bind') returns a tibble without warning when types match", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\n2", f2)
  expect_no_warning(result <- read_files(c(a = f1, b = f2), out = "bind"))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_false("source" %in% names(result))
})

test_that("read_files(out = 'bind') warns and falls back when types differ", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\na", f2)
  expect_warning(
    result <- read_files(c(a = f1, b = f2), out = "bind"),
    regexp = "types differ"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
})

test_that("read_files(out = 'bind') adds source column when .id is set", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\n2", f2)
  result <- read_files(c(a = f1, b = f2), out = "bind", .id = "file")
  expect_true("file" %in% names(result))
})

test_that("read_files(out = 'bind') has no source column by default", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\n2", f2)
  result <- read_files(c(a = f1, b = f2), out = "bind")
  expect_false("source" %in% names(result))
})

test_that("read_files(out = 'unpack') assigns variables to environment", {
  f1 <- withr::local_tempfile(fileext = ".csv")
  f2 <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f1)
  writeLines("x\n2", f2)
  env <- new.env()
  read_files(c(a = f1, b = f2), out = "unpack", .envir = env)
  expect_true(exists("a", envir = env))
  expect_true(exists("b", envir = env))
})

test_that("read_files(out = 'unpack') returns invisibly", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  env <- new.env()
  result <- read_files(c(z = f), out = "unpack", .envir = env)
  expect_type(result, "list")
  expect_named(result, "z")
})

test_that("read_files(out = 'unpack') aborts on conflict without .overwrite", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  env <- new.env()
  env$a <- "existing"
  expect_error(
    read_files(c(a = f), out = "unpack", .envir = env),
    class = "rlang_error"
  )
})

test_that("read_files(out = 'unpack', .overwrite = TRUE) overwrites existing variables", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  env <- new.env()
  env$a <- "old"
  read_files(c(a = f), out = "unpack", .envir = env, .overwrite = TRUE)
  expect_s3_class(env$a, "data.frame")
})

test_that("read_files() warns on a multi-sheet Excel and reads the first", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")
  f <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(One = data.frame(x = 1), Two = data.frame(y = 2)), f)
  expect_warning(d1 <- read_files(f), "sheets")
  expect_equal(names(d1), "x")                       # the first sheet
  expect_no_warning(d2 <- read_files(f, sheet = "Two"))   # naming a sheet silences it
  expect_equal(names(d2), "y")
})
