test_that("split_by() returns a named list", {
  df <- data.frame(g = c("a", "a", "b"), x = 1:3)
  result <- split_by(df, g)
  expect_type(result, "list")
  expect_setequal(names(result), c("a", "b"))
})

test_that("split_by() each element contains only the matching rows", {
  df <- data.frame(g = c("a", "b", "a"), x = c(1, 2, 3))
  result <- split_by(df, g)
  expect_equal(nrow(result[["a"]]), 2)
  expect_equal(nrow(result[["b"]]), 1)
})

test_that("split_by() concatenates multiple group keys with .sep", {
  df <- data.frame(g1 = c("a", "b"), g2 = c("x", "y"), v = 1:2)
  result <- split_by(df, g1, g2, .sep = "-")
  expect_setequal(names(result), c("a-x", "b-y"))
})
