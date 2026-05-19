test_that("bind_files() row-binds a list of data frames", {
  df1 <- tibble::tibble(x = 1L, y = "a")
  df2 <- tibble::tibble(x = 2L, y = "b")
  result <- bind_files(list(a = df1, b = df2))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$source, c("a", "b"))
})

test_that("bind_files() respects custom .id name", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = 2L)
  result <- bind_files(list(p = df1, q = df2), .id = "file")
  expect_true("file" %in% names(result))
  expect_false("source" %in% names(result))
})

test_that("bind_files() aborts on non-list input", {
  expect_error(bind_files(data.frame(x = 1)), class = "rlang_error")
})

test_that("bind_files() aborts on type mismatch without .guess", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = "a")
  expect_error(bind_files(list(df1, df2)), class = "rlang_error")
})

test_that("bind_files(.guess = TRUE) handles type mismatches", {
  df1 <- data.frame(x = 1L)
  df2 <- data.frame(x = "2")
  result <- bind_files(list(df1, df2), .guess = TRUE)
  expect_equal(nrow(result), 2)
})
