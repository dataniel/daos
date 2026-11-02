test_that("nowf() returns a single character string", {
  result <- nowf()
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("nowf() default format is 8-digit YYYYMMDD", {
  expect_match(nowf(), "^\\d{8}$")
  expect_identical(nowf(), format(Sys.Date(), "%Y%m%d"))
})

test_that("nowf() respects a custom format", {
  expect_match(nowf("%Y"), "^\\d{4}$")
  expect_match(nowf("%Y-%m-%d"), "^\\d{4}-\\d{2}-\\d{2}$")
})

test_that("named formats give their documented shape", {
  expect_match(nowf("date"), "^\\d{8}$")
  expect_match(nowf("datetime"), "^\\d{8}_\\d{6}$")
  expect_match(nowf("iso"), "^\\d{4}-\\d{2}-\\d{2}$")
  expect_match(nowf("month"), "^\\d{6}$")
  expect_match(nowf("year"), "^\\d{4}$")
  expect_match(nowf("time"), "^\\d{6}$")
  expect_match(nowf("stamp"), "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$")
})

test_that("a name typo is an error, not a file name", {
  expect_error(nowf("datetiem"), "Unknown format name")
  expect_error(nowf("datetiem"), "datetime")
  expect_error(nowf(1), "single format")
  expect_error(nowf(c("date", "iso")), "single format")
  expect_error(nowf(NA_character_), "single format")
})
