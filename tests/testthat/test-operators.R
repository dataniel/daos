test_that("%??% returns default for blank values", {
  expect_equal(NULL    %??% "x", "x")
  expect_equal(NA      %??% "x", "x")
  expect_equal(""      %??% "x", "x")
  expect_equal(c(NA, NA) %??% "x", "x")
  expect_equal(character(0) %??% "x", "x")
})

test_that("%??% returns x for non-blank values", {
  expect_equal(42        %??% 0,   42)
  expect_equal("hello"   %??% "x", "hello")
  expect_equal(c(1, NA)  %??% 0,   c(1, NA))
  expect_equal(FALSE     %??% TRUE, FALSE)
})

test_that("%like% matches correctly and preserves NA", {
  x <- c("sedan", "SUV", NA, "truck")
  result <- x %like% "^S"
  expect_equal(result, c(FALSE, TRUE, NA, FALSE))
})

test_that("%like% returns logical vector same length as input", {
  x <- c("a1", "b", NA)
  result <- x %like% "\\d"
  expect_type(result, "logical")
  expect_length(result, 3)
})

test_that("%like% returns FALSE (not NA) for non-matching non-NA values", {
  expect_equal("abc" %like% "\\d", FALSE)
})
