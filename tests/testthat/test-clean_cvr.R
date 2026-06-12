test_that("clean_cvr() strips dashes and spaces", {
  expect_equal(clean_cvr("12 34 56 78"), "12345678")
  expect_equal(clean_cvr("1234-5678"), "12345678")
})

test_that("clean_cvr() strips a leading DK prefix case-insensitively", {
  expect_equal(clean_cvr("DK12345678"), "12345678")
  expect_equal(clean_cvr("dk12345678"), "12345678")
  expect_equal(clean_cvr("DK 12345678"), "12345678")
})

test_that("clean_cvr() does not zero-pad seven-digit values", {
  expect_equal(clean_cvr("2345678"), "2345678")
})

test_that("clean_cvr() coerces numeric input", {
  expect_equal(clean_cvr(12345678), "12345678")
})

test_that("clean_cvr() preserves NA", {
  expect_equal(clean_cvr(c(NA, "DK12345678")), c(NA, "12345678"))
})
