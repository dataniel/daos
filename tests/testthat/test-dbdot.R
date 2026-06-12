test_that("dbdot() inserts dots after every second digit", {
  expect_equal(dbdot("011100"), "01.11.00")
  expect_equal(dbdot("0111"), "01.11")
  expect_equal(dbdot("011"), "01.1")
  expect_equal(dbdot("01"), "01")
})

test_that("dbdot() normalises partially dotted input", {
  expect_equal(dbdot("01.1100"), "01.11.00")
  expect_equal(dbdot("01.11.00"), "01.11.00")
  expect_equal(dbdot("01 11 00"), "01.11.00")
})

test_that("dbdot() is idempotent", {
  x <- c("011100", "01.1100", "0111")
  expect_equal(dbdot(dbdot(x)), dbdot(x))
})

test_that("dbdot() does not invent digits for odd-length codes", {
  # a 5-digit code (e.g. Excel-lost leading zero) stays visibly odd
  expect_equal(dbdot("11100"), "11.10.0")
})

test_that("dbdot() leaves non-digit values untouched", {
  expect_equal(dbdot("A"), "A")
})

test_that("dbdot() coerces numeric input and preserves NA", {
  expect_equal(dbdot(11100), "11.10.0")
  expect_equal(dbdot(c(NA, "011100")), c(NA, "01.11.00"))
})
