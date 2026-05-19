test_that("view_types() returns a tibble with a column per dataset", {
  df1 <- data.frame(x = 1L, y = "a")
  df2 <- data.frame(x = 1L, y = "b")
  result <- view_types(df1, df2)
  expect_s3_class(result, "tbl_df")
  expect_true("column" %in% names(result))
  expect_equal(ncol(result), 3)  # column + df1 + df2
})

test_that("view_types(diff = TRUE) returns only mismatched columns", {
  df1 <- data.frame(x = 1L,  y = "a")
  df2 <- data.frame(x = 1.0, y = "b")
  result <- view_types(df1, df2, diff = TRUE)
  expect_equal(result$column, "x")
})

test_that("view_types(diff = TRUE) returns 0 rows when all types match", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = 2L)
  result <- view_types(df1, df2, diff = TRUE)
  expect_equal(nrow(result), 0)
})

test_that("view_types(focus = ...) returns 0 rows when type matches", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = 2L)
  result <- view_types(df1, df2, focus = c(x = "int"))
  expect_equal(nrow(result), 0)
})

test_that("view_types(focus = ...) returns offending datasets when type mismatches", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = 1.0)
  result <- view_types(df1, df2, focus = c(x = "int"))
  expect_equal(nrow(result), 1)
})

test_that("view_types() aborts on non-data-frame input", {
  expect_error(view_types(list(x = 1)), class = "rlang_error")
})
