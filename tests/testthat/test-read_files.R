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
  dir <- withr::local_tempdir()
  writeLines("x\n1", file.path(dir, "one.csv"))
  writeLines("x\n1", file.path(dir, "two.csv"))
  result <- read_files(file.path(dir, c("one.csv", "two.csv")))
  expect_named(result, c("one", "two"))
})

test_that("read_files() falls back to the filename for unnamed elements", {
  withr::local_dir(withr::local_tempdir())
  writeLines("x\n1", "one.csv")
  writeLines("x\n1", "two.csv")
  result <- read_files(c(a = "one.csv", "two.csv"))
  expect_named(result, c("a", "two"))
})

test_that("read_files() rejects a name on a pattern that expands to several files", {
  withr::local_dir(withr::local_tempdir())
  for (i in 1:2) writeLines("x\n1", paste0("f", i, ".csv"))
  expect_snapshot(read_files(c(a = "f{1:2}.csv")), error = TRUE)
})

test_that("read_files() warns when files share a name, and refuses to unpack them", {
  withr::local_dir(withr::local_tempdir())
  dir.create("a"); dir.create("b")
  writeLines("x\n1", "a/data.csv")
  writeLines("x\n2", "b/data.csv")
  expect_snapshot(result <- read_files(c("a/data.csv", "b/data.csv")))
  expect_length(result, 2)
  expect_no_warning(read_files(c("a/data.csv", "b/data.csv"), out = "bind"))
  env <- new.env()
  expect_snapshot(
    read_files(c("a/data.csv", "b/data.csv"), out = "unpack", .envir = env),
    error = TRUE
  )
})

test_that("read_files() reads CSV silently", {
  withr::local_dir(withr::local_tempdir())
  writeLines("x;y\n1,5;a", "a.csv")
  expect_silent(result <- read_files("a.csv"))
  expect_equal(result$x, 1.5)
})

test_that("read_files() keeps the decimal comma when a locale is passed for its encoding", {
  withr::local_dir(withr::local_tempdir())
  writeLines("x\n1,5", "a.csv")
  result <- read_files("a.csv", locale = readr::locale(encoding = "latin1"))
  expect_equal(result$x, 1.5)
})

test_that("read_files() lists missing files with their full path, capped at ten", {
  expect_snapshot(read_files("no/such/dir/f{1:12}.csv"), error = TRUE)
})

test_that("read_files() reads every file and reports all failures together", {
  withr::local_dir(withr::local_tempdir())
  writeLines("{bad", "x.json")
  writeLines("[1]", "ok.json")
  writeLines("{worse", "y.json")
  expect_snapshot(read_files(c("x.json", "ok.json", "y.json")), error = TRUE)
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

test_that("read_files() aborts on unsupported extension before reading anything", {
  withr::local_dir(withr::local_tempdir())
  writeLines("data", "a.xyz")
  writeLines("x\n1", "b.csv")
  expect_snapshot(read_files(c("b.csv", "a.xyz")), error = TRUE)
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

test_that("read_files(out = 'bind') re-types only the conflicting columns", {
  withr::local_dir(withr::local_tempdir())
  saveRDS(tibble::tibble(code = "12", x = 1,   d = as.Date("2024-01-01")), "a.rds")
  saveRDS(tibble::tibble(code = "13", x = "b", d = as.Date("2024-02-01")), "b.rds")
  expect_snapshot(result <- read_files(c("a.rds", "b.rds"), out = "bind", .id = "f"))
  expect_type(result$code, "character")   # agreed on character: left alone
  expect_s3_class(result$d, "Date")
  expect_equal(result$x, c("1", "b"))
  expect_equal(result$f, c("a", "b"))
})

test_that("read_files(out = 'bind') re-guesses a conflict that resolves to a number", {
  withr::local_dir(withr::local_tempdir())
  saveRDS(tibble::tibble(x = 1L), "a.rds")
  saveRDS(tibble::tibble(x = "2"), "b.rds")
  expect_warning(result <- read_files(c("a.rds", "b.rds"), out = "bind"), "x")
  expect_equal(result$x, c(1, 2))
})

test_that("read_files(out = 'bind') names the files that are not data frames", {
  withr::local_dir(withr::local_tempdir())
  writeLines("hello", "a.txt")
  writeLines("x\n1", "b.csv")
  expect_snapshot(read_files(c("a.txt", "b.csv"), out = "bind"), error = TRUE)
})

test_that("read_files(out = 'bind') makes .id numeric for numeric names", {
  withr::local_dir(withr::local_tempdir())
  writeLines("x\n1", "a.csv")
  writeLines("x\n2", "b.csv")
  result <- read_files(c("a.csv", "b.csv"), names = 2020:2021, out = "bind", .id = "year")
  expect_equal(result$year, c(2020, 2021))
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

test_that("read_files(out = 'unpack') also sees hidden names as conflicts", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  env <- new.env()
  env$.a <- "existing"
  expect_error(read_files(c(.a = f), out = "unpack", .envir = env), "already exist")
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
  expect_warning(d1 <- read_files(f), "sheet")
  expect_equal(names(d1), "x")                       # the first sheet
  expect_no_warning(d2 <- read_files(f, sheet = "Two"))   # naming a sheet silences it
  expect_equal(names(d2), "y")
})

test_that("read_files() reports all multi-sheet workbooks in one warning", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")
  withr::local_dir(withr::local_tempdir())
  writexl::write_xlsx(list(One = data.frame(x = 1), Two = data.frame(x = 2)), "a.xlsx")
  writexl::write_xlsx(list(One = data.frame(x = 1), B = data.frame(x = 2), C = data.frame(x = 3)), "b.xlsx")
  writexl::write_xlsx(list(One = data.frame(x = 1)), "c.xlsx")
  expect_snapshot(result <- read_files(c("a.xlsx", "b.xlsx", "c.xlsx")))
  expect_length(result, 3)
})
