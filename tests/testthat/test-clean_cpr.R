test_that("clean_cpr() strips dashes and spaces", {
  expect_equal(clean_cpr("111111-1118"), "1111111118")
  expect_equal(clean_cpr("111111 1118"), "1111111118")
})

test_that("clean_cpr() zero-pads nine-digit values", {
  expect_equal(clean_cpr("101004007"), "0101004007")
  expect_equal(clean_cpr("101004-007"), "0101004007")
})

test_that("clean_cpr() leaves malformed values cleaned but unpadded", {
  expect_equal(clean_cpr("notacpr"), "notacpr")
  expect_equal(clean_cpr("12345678"), "12345678")
  expect_equal(clean_cpr("12345678a"), "12345678a")
})

test_that("clean_cpr() coerces numeric input", {
  expect_equal(clean_cpr(1111111118), "1111111118")
  expect_equal(clean_cpr(101004007), "0101004007")
})

test_that("clean_cpr() preserves NA", {
  expect_equal(clean_cpr(c(NA, "111111-1118")), c(NA, "1111111118"))
})

test_that("clean_cpr() matches the cleaning inside add_cpr_info()", {
  raw <- c("0101004007", "111111-1118", "101004007", "notacpr")
  df  <- data.frame(pnr = raw, stringsAsFactors = FALSE)
  expect_equal(add_cpr_info(df, pnr, add = "valid")$pnr, clean_cpr(raw))
})
