test_that("clean_db07() inserts dots after every second digit", {
  expect_equal(clean_db07("011100"), "01.11.00")
  expect_equal(clean_db07("0111"), "01.11")
  expect_equal(clean_db07("011"), "01.1")
  expect_equal(clean_db07("01"), "01")
})

test_that("clean_db07() normalises partially dotted input", {
  expect_equal(clean_db07("01.1100"), "01.11.00")
  expect_equal(clean_db07("01.11.00"), "01.11.00")
  expect_equal(clean_db07("01 11 00"), "01.11.00")
})

test_that("clean_db07() is idempotent", {
  x <- c("011100", "01.1100", "0111")
  expect_equal(clean_db07(clean_db07(x)), clean_db07(x))
})

test_that("clean_db07() does not invent digits for odd-length codes", {
  # a 5-digit code (e.g. Excel-lost leading zero) stays visibly odd
  expect_equal(clean_db07("11100"), "11.10.0")
})

test_that("clean_db07() leaves non-digit values untouched", {
  expect_equal(clean_db07("A"), "A")
})

test_that("clean_db07() coerces numeric input and preserves NA", {
  expect_equal(clean_db07(11100), "11.10.0")
  expect_equal(clean_db07(c(NA, "011100")), c(NA, "01.11.00"))
})
