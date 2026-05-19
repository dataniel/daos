test_that("nowf() returns a single character string", {
  result <- nowf()
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("nowf() default format is 8-digit YYYYMMDD", {
  expect_match(nowf(), "^\\d{8}$")
})

test_that("nowf() respects a custom format", {
  expect_match(nowf("%Y"), "^\\d{4}$")
  expect_match(nowf("%Y-%m-%d"), "^\\d{4}-\\d{2}-\\d{2}$")
})
