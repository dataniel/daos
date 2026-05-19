test_that("expect_empty() succeeds silently on empty data frame", {
  expect_no_warning(expect_no_error(
    expect_empty(data.frame())
  ))
})

test_that("expect_empty() returns data invisibly", {
  df <- data.frame()
  result <- expect_empty(df)
  expect_equal(result, df)
})

test_that("expect_empty() warns when data has rows", {
  expect_warning(
    expect_empty(data.frame(x = 1), warn_msg = "not empty"),
    "not empty"
  )
})

test_that("expect_empty() aborts when abort_msg is set and data has rows", {
  expect_error(
    expect_empty(data.frame(x = 1), abort_msg = "must be empty"),
    "must be empty"
  )
})

test_that("expect_empty() aborts on non-data-frame input", {
  expect_error(expect_empty(list()), class = "rlang_error")
  expect_error(expect_empty("text"), class = "rlang_error")
})

test_that("expect_empty() writes to log file", {
  log <- withr::local_tempfile(fileext = ".log")
  expect_empty(data.frame(), success_msg = "OK", log = log)
  lines <- readLines(log)
  expect_true(any(grepl("OK", lines)))
})
