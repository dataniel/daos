make_ta_df <- function() {
  tibble::tibble(
    nrnr  = "12345",
    trans = "123456",
    brch  = "1234",
    bas   = 100.00,
    eng   =  50.00,
    det   =  30.00,
    afg   =  10.00,
    moms  =   5.00,
    kbx   =   2.00
  )
}

ta_cols <- c("nrnr", "trans", "brch", "bas", "eng", "det", "afg", "moms", "kbx")

expect_round_trip <- function(df) {
  path <- withr::local_tempfile()
  write_ta(df, path)
  result <- read_ta(path)
  # Exact comparison: nothing may be rounded on the way through the file.
  expect_identical(as.list(result[ta_cols]), as.list(df[ta_cols]))
}

test_that("write_ta() round-trips through read_ta() for the nine columns", {
  expect_round_trip(make_ta_df())
})

test_that("write_ta() round-trips decimals, negatives, short codes and NA exactly", {
  df <- tibble::tibble(
    nrnr  = c("12345", "1",    NA),
    trans = c("0100",  "123456", "0700"),
    brch  = c("1234",  "07",   "A1"),
    bas   = c(100.6,   -1234567.891, 1e12),
    eng   = c(-0.4,    0.125,  NA),
    det   = c(0,       12345678901, -9999999999),
    afg   = c(1/4,     -0.001, 3),
    moms  = c(NA,      5.5,    0),
    kbx   = c(2,       99.99,  -7)
  )
  expect_round_trip(df)
})

test_that("write_ta() writes whole numbers without decimals", {
  path <- withr::local_tempfile()
  write_ta(make_ta_df(), path)
  expect_false(grepl(".", readLines(path), fixed = TRUE))
})

test_that("write_ta() returns path invisibly", {
  path <- withr::local_tempfile()
  result <- write_ta(make_ta_df(), path)
  expect_equal(result, path)
})

test_that("write_ta() handles NA as blank fields", {
  df <- make_ta_df()
  df$eng <- NA_real_
  path <- withr::local_tempfile()
  write_ta(df, path)

  result <- read_ta(path)
  expect_true(is.na(result$eng))
})

test_that("write_ta() derives moms when column is absent", {
  df <- tibble::tibble(
    nrnr  = c("12345", "12345", "12345"),
    trans = c("0100",  "0700",  "0200"),
    brch  = "1234",
    bas   = 100.00,
    eng   =  50.00,
    det   =  30.00,
    afg   =  10.00,
    kbx   =   2.00
  )
  path <- withr::local_tempfile()
  expect_message(write_ta(df, path), "`moms` not found")

  result <- read_ta(path)
  expect_true(is.na(result$moms[1]))   # trans 0100 -> NA
  expect_true(is.na(result$moms[2]))   # trans 0700 -> NA
  expect_equal(result$moms[3], 0)      # other trans -> 0
})

test_that("write_ta() errors on unknown columns", {
  df <- make_ta_df()
  df$prim <- 99
  expect_error(write_ta(df, tempfile()), "Remove: prim")
})

test_that("write_ta() errors on a missing column instead of shifting fields", {
  df <- make_ta_df()
  df$det <- NULL
  path <- withr::local_tempfile()
  expect_error(write_ta(df, path), "missing column det")
  expect_false(file.exists(path))
})

test_that("write_ta() errors on character values that would not read back", {
  df <- make_ta_df()[rep(1, 3), ]
  df$nrnr  <- c("1234567", "", " 12")
  path <- withr::local_tempfile()
  expect_snapshot(write_ta(df, path), error = TRUE)
  expect_false(file.exists(path))
})

test_that("write_ta() errors on numbers it cannot write exactly in the field", {
  df <- make_ta_df()[rep(1, 3), ]
  df$eng <- c(123456789012, 1/3, 0.1 + 0.2)
  path <- withr::local_tempfile()
  expect_snapshot(write_ta(df, path), error = TRUE)
  expect_false(file.exists(path))
})

test_that("write_ta() lists at most 10 problems", {
  df <- make_ta_df()[rep(1, 12), ]
  df$nrnr <- "1234567"
  expect_error(write_ta(df, withr::local_tempfile()), "and 2 more")
})
