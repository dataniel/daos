test_that("flag_duplicates() adds isdup and dupid columns", {
  df <- data.frame(x = c(1, 1, 2))
  result <- flag_duplicates(df)
  expect_true("isdup" %in% names(result))
  expect_true("dupid" %in% names(result))
  expect_equal(result$isdup, c(TRUE, TRUE, FALSE))
  expect_equal(result$dupid[3], 0L)
  expect_equal(result$dupid[1], result$dupid[2])
})

test_that("flag_duplicates() treats all rows as unique when no dupes", {
  df <- data.frame(x = 1:3)
  result <- flag_duplicates(df)
  expect_true(all(!result$isdup))
  expect_true(all(result$dupid == 0L))
})

test_that("flag_duplicates() respects column selection", {
  df <- data.frame(x = c(1, 1), y = c("a", "b"))
  result <- flag_duplicates(df, x)
  expect_true(all(result$isdup))
})

test_that("flag_duplicates() places isdup and dupid first", {
  df <- data.frame(x = 1:2, y = letters[1:2])
  result <- flag_duplicates(df)
  expect_equal(names(result)[1:2], c("isdup", "dupid"))
})

test_that("flag_duplicates() aborts on non-data-frame", {
  expect_error(flag_duplicates(list(x = 1)), class = "rlang_error")
})

test_that("flag_duplicates() aborts on non-atomic columns", {
  df <- data.frame(x = 1:2)
  df$y <- list(1, 2)
  expect_error(flag_duplicates(df, y), class = "rlang_error")
})
