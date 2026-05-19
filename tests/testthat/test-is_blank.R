test_that("is_blank() returns TRUE for blank values", {
  expect_true(is_blank(NULL))
  expect_true(is_blank(NA))
  expect_true(is_blank(""))
  expect_true(is_blank(c(NA, NA)))
  expect_true(is_blank(character(0)))
  expect_true(is_blank(integer(0)))
  expect_true(is_blank(c("", "")))
})

test_that("is_blank() returns FALSE for non-blank values", {
  expect_false(is_blank(0))
  expect_false(is_blank("text"))
  expect_false(is_blank(c(1, NA)))
  expect_false(is_blank(FALSE))
  expect_false(is_blank(c("", "x")))
})
