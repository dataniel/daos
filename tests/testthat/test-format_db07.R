test_that("format_db07() inserts dots after every second digit", {
  expect_equal(format_db07("011100"), "01.11.00")
  expect_equal(format_db07("0111"), "01.11")
  expect_equal(format_db07("011"), "01.1")
  expect_equal(format_db07("01"), "01")
})

test_that("format_db07() normalises partially dotted input", {
  expect_equal(format_db07("01.1100"), "01.11.00")
  expect_equal(format_db07("01.11.00"), "01.11.00")
  expect_equal(format_db07("01 11 00"), "01.11.00")
})

test_that("format_db07() is idempotent", {
  x <- c("011100", "01.1100", "0111")
  expect_equal(format_db07(format_db07(x)), format_db07(x))
})

test_that("format_db07() does not invent digits for odd-length codes", {
  # a 5-digit code (e.g. Excel-lost leading zero) stays visibly odd
  expect_equal(format_db07("11100"), "11.10.0")
})

test_that("format_db07() leaves non-digit values untouched", {
  expect_equal(format_db07("A"), "A")
})

test_that("format_db07() coerces numeric input and preserves NA", {
  expect_equal(format_db07(11100), "11.10.0")
  expect_equal(format_db07(c(NA, "011100")), c(NA, "01.11.00"))
})

test_that("format_db07() converts mixed formats in either direction", {
  x <- c("011100", "01.1100", "01.11.00", "01 11 00", "01\t11\n00")
  expect_equal(format_db07(x), rep("01.11.00", 5))
  expect_equal(format_db07(x, "compact"), rep("011100", 5))
  levels <- c("01", "011", "0111", "011100", NA_character_)
  expect_equal(format_db07(format_db07(levels), "compact"), levels)
  expect_equal(format_db07(levels, "compact"), levels)
})

test_that("format_db07() handles empty, missing and numeric input", {
  for (format in c("dotted", "compact")) {
    expect_identical(format_db07(character(), format), character())
    expect_identical(format_db07(c("", NA_character_), format), c("", NA_character_))
  }
  expect_equal(format_db07(c(11100, NA_real_), "compact"), c("11100", NA_character_))
})

test_that("format_db07() rejects an unsupported output format", {
  expect_error(format_db07("011100", "unknown"), "'arg'")
})
