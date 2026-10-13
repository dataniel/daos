make_ta2_df <- function() {
  tibble::tibble(
    nrnr  = "123456",
    trans = "12345",
    brch  = "12345",
    bas   = 100,
    eng   =  50,
    det   =  30,
    afg   =  10,
    moms  =   5,
    kbx   =   2
  )
}

ta2_cols <- c("nrnr", "trans", "brch", "bas", "eng", "det", "afg", "moms", "kbx")

expect_round_trip2 <- function(df) {
  path <- withr::local_tempfile()
  write_ta2(df, path)
  result <- read_ta2(path)
  # Exact comparison: nothing may be rounded on the way through the file.
  expect_identical(as.list(result[ta2_cols]), as.list(df[ta2_cols]))
}

test_that("write_ta2() writes the 140-character layout", {
  path <- withr::local_tempfile()
  write_ta2(make_ta2_df(), path)
  line <- readLines(path)
  expect_equal(nchar(line), 140)
  expect_equal(substr(line, 1, 6), "123456")
  expect_equal(substr(line, 7, 16), strrep(" ", 10))
  expect_equal(substr(line, 17, 21), "12345")
  expect_equal(substr(line, 22, 30), strrep(" ", 9))
  expect_equal(substr(line, 31, 35), "12345")
  expect_equal(substr(line, 36, 60), formatC("100", width = 25))
  expect_equal(substr(line, 125, 140), formatC("2", width = 16))
})

test_that("write_ta2() round-trips through read_ta2() for the nine columns", {
  expect_round_trip2(make_ta2_df())
})

test_that("write_ta2() round-trips decimals, negatives, short codes and NA exactly", {
  df <- tibble::tibble(
    nrnr  = c("123456", "1",     NA),
    trans = c("0100",   "12345", "0700"),
    brch  = c("12345",  "07",    NA),
    bas   = c(100.6,    -1234567.891, 1e20),
    eng   = c(-0.4,     0.125,   NA),
    det   = c(0,        123456789012345, -99999999999999),
    afg   = c(1/4,      -0.001,  3),
    moms  = c(NA,       5.5,     0),
    kbx   = c(2,        99.99,   -7)
  )
  expect_round_trip2(df)
})

test_that("write_ta2() keeps lines 140 characters when the last field is NA", {
  df <- make_ta2_df()
  df$kbx <- NA_real_
  path <- withr::local_tempfile()
  write_ta2(df, path)
  expect_equal(nchar(readLines(path)), 140)
  expect_true(is.na(read_ta2(path)$kbx))
})

test_that("write_ta2() returns path invisibly", {
  path <- withr::local_tempfile()
  expect_invisible(write_ta2(make_ta2_df(), path))
  expect_equal(write_ta2(make_ta2_df(), path), path)
})

test_that("write_ta2() derives moms when column is absent", {
  df <- make_ta2_df()[rep(1, 3), ]
  df$trans <- c("0100", "0700", "0200")
  df$moms <- NULL
  path <- withr::local_tempfile()
  expect_message(write_ta2(df, path), "`moms` not found")
  expect_equal(read_ta2(path)$moms, c(NA, NA, 0))
})

test_that("write_ta2() errors on unknown and missing columns", {
  df <- make_ta2_df()
  df$prim <- 99
  expect_error(write_ta2(df, tempfile()), "write_ta2\\(\\) only supports .* Remove: prim")

  df <- make_ta2_df()
  df$det <- NULL
  path <- withr::local_tempfile()
  expect_error(write_ta2(df, path), "missing column det")
  expect_false(file.exists(path))
})

test_that("write_ta2() errors on values that would not read back", {
  df <- make_ta2_df()[rep(1, 3), ]
  df$nrnr <- c("1234567", "", " 12")
  df$eng  <- c(1/3, 1, 1)
  path <- withr::local_tempfile()
  expect_snapshot(write_ta2(df, path), error = TRUE)
  expect_false(file.exists(path))
})
