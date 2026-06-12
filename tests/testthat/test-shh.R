test_that("shh() suppresses messages", {
  expect_no_message(shh(message("hello")))
})

test_that("shh() suppresses warnings", {
  expect_no_warning(shh(warning("oops")))
})

test_that("shh() returns the expression value unchanged", {
  expect_equal(shh(1 + 1), 2)
  expect_equal(shh({ x <- 42; x }), 42)
})
