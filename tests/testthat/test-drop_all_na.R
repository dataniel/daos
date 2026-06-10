make_df <- function() {
  tibble::tibble(
    a = c(1, NA, 3),
    b = c(NA_real_, NA_real_, NA_real_),
    c = c("x", NA, "z")
  )
}

test_that("drops both all-NA rows and all-NA columns by default", {
  out <- drop_all_na(make_df())
  expect_equal(names(out), c("a", "c"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$a, c(1, 3))
})

test_that("which = 'rows' only drops fully-NA rows", {
  out <- drop_all_na(make_df(), which = "rows")
  expect_equal(names(out), c("a", "b", "c"))   # column b is kept
  expect_equal(nrow(out), 2L)
})

test_that("which = 'cols' only drops fully-NA columns", {
  out <- drop_all_na(make_df(), which = "cols")
  expect_equal(names(out), c("a", "c"))
  expect_equal(nrow(out), 3L)                   # all rows kept
})

test_that("which is partially matched", {
  expect_equal(names(drop_all_na(make_df(), which = "col")), c("a", "c"))
})

test_that("preserves input class (data.frame stays data.frame)", {
  df <- data.frame(a = c(1, NA), b = c(NA, NA))
  out <- drop_all_na(df)
  expect_s3_class(out, "data.frame")
  expect_false(inherits(out, "tbl_df"))
  expect_equal(names(out), "a")
})

test_that("a frame with no NA is returned unchanged", {
  df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"))
  expect_equal(drop_all_na(df), df)
})

test_that("an all-NA frame drops every column (rows are left untouched)", {
  # Columns are cleaned first, leaving a 0-column frame; the row step is then
  # skipped because there are no columns left to judge a row by.
  df <- tibble::tibble(a = c(NA, NA), b = c(NA, NA))
  out <- drop_all_na(df)
  expect_equal(ncol(out), 0L)
  expect_equal(nrow(out), 2L)
})

test_that("handles a zero-row data frame", {
  df <- tibble::tibble(a = numeric(0), b = character(0))
  out <- drop_all_na(df)
  expect_equal(nrow(out), 0L)
  expect_equal(names(out), c("a", "b"))   # no column is all-NA over 0 rows
})

test_that("handles a zero-column data frame without dropping rows", {
  df <- make_df()[, 0]
  out <- drop_all_na(df, which = "rows")
  expect_equal(nrow(out), 3L)
})

test_that("aborts on non-data-frame input", {
  expect_error(drop_all_na(1:10), "data frame or tibble")
})

test_that("aborts on an invalid which value", {
  expect_error(drop_all_na(make_df(), which = "banana"))
})
