test_that("view_types() returns a tibble with column, status and one column per dataset", {
  df1 <- data.frame(x = 1L, y = "a")
  df2 <- data.frame(x = 1L, y = "b")
  result <- view_types(df1, df2)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("column", "status", "df1", "df2"))
  expect_equal(result$status, c("ok", "ok"))
})

test_that("view_types() classifies conflict, coercible and missing", {
  df1 <- data.frame(a = 1L,  b = "a", c = 1, d = NA, e = Sys.Date())
  df2 <- data.frame(a = 1.0, b = 2,   f = 1, d = "x", e = Sys.time())
  result <- view_types(df1, df2)
  status <- setNames(result$status, result$column)
  expect_equal(status[["a"]], "coercible")  # int + dbl
  expect_equal(status[["b"]], "conflict")   # chr + dbl
  expect_equal(status[["c"]], "missing")
  expect_equal(status[["f"]], "missing")
  expect_equal(status[["d"]], "coercible")  # all-NA lgl + chr
  expect_equal(status[["e"]], "coercible")  # date + dttm
  expect_true(is.na(result$df2[result$column == "c"]))
})

test_that("view_types() treats a non-NA lgl vs chr as a conflict", {
  df1 <- data.frame(x = TRUE)
  df2 <- data.frame(x = "a")
  expect_equal(view_types(df1, df2)$status, "conflict")
})

test_that("view_types() reports conflict over missing", {
  df1 <- data.frame(x = 1)
  df2 <- data.frame(x = "a")
  df3 <- data.frame(y = 1)
  result <- view_types(df1, df2, df3)
  expect_equal(result$status[result$column == "x"], "conflict")
})

test_that("view_types(diff = TRUE) returns only conflicting columns", {
  df1 <- data.frame(x = 1L,  y = "a", z = 1)
  df2 <- data.frame(x = 1.0, y = 2)
  result <- view_types(df1, df2, diff = TRUE)
  expect_equal(result$column, "y")
})

test_that("view_types(diff = TRUE) returns 0 rows when frames bind", {
  df1 <- data.frame(x = 1L, y = 1)
  df2 <- data.frame(x = 2.5)
  result <- view_types(df1, df2, diff = TRUE)
  expect_equal(nrow(result), 0)
})

test_that("view_types() accepts a named list of data frames", {
  lst <- list(a = data.frame(x = 1L), b = data.frame(x = "a"))
  result <- view_types(lst)
  expect_named(result, c("column", "status", "a", "b"))
  expect_equal(result$status, "conflict")
})

test_that("view_types() names unnamed list elements by position", {
  lst <- list(data.frame(x = 1L), data.frame(x = 2L))
  expect_named(view_types(lst), c("column", "status", "1", "2"))
})

test_that("view_types() accepts a spliced list", {
  lst <- list(a = data.frame(x = 1L), data.frame(x = 2L))
  expect_named(view_types(!!!lst), c("column", "status", "a", "2"))
})

test_that("view_types() makes dataset names unique and avoids reserved names", {
  df <- data.frame(x = 1L)
  expect_named(view_types(df, df), c("column", "status", "df", "df.1"))
  expect_named(view_types(list(status = df)), c("column", "status", "status.1"))
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
  expect_named(result, c("column", "status", "df2"))
})

test_that("view_types(focus = ...) handles several columns", {
  df1 <- data.frame(x = 1L,  y = "a", z = 1)
  df2 <- data.frame(x = 1.0, y = "b")
  df3 <- data.frame(x = 1L,  z = 1)
  result <- view_types(df1, df2, df3, focus = c(x = "int", y = "chr", z = "dbl"))
  expect_equal(result$column, c("x", "y", "z"))
  expect_named(result, c("column", "status", "df2", "df3"))
})

test_that("view_types(focus = ...) names every missing column in the error", {
  df <- data.frame(x = 1L)
  expect_error(view_types(df, focus = c(a = "int", b = "chr")), "a.*b")
})

test_that("view_types(focus = ...) rejects malformed input", {
  df <- data.frame(x = 1L)
  expect_error(view_types(df, focus = "int"), "named character vector")
  expect_error(view_types(df, focus = c(x = "int", x = "dbl")), "unique names")
})

test_that("view_types() aborts on non-data-frame input", {
  expect_error(view_types(list(x = 1)), "data frames")
  expect_error(view_types(data.frame(x = 1), list(data.frame(x = 1))), "splice")
  expect_error(view_types(list()), "empty")
  expect_error(view_types(), "at least one")
})
