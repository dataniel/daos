test_that("quiet() suppresses messages", {
  expect_no_message(quiet(message("hello")))
})

test_that("quiet() suppresses warnings", {
  expect_no_warning(quiet(warning("oops")))
})

test_that("quiet() returns the expression value unchanged", {
  expect_equal(quiet(1 + 1), 2)
  expect_equal(quiet({ x <- 42; x }), 42)
})
