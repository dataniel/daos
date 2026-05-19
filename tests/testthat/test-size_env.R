test_that("size_env() returns a tibble with name, size, pretty columns", {
  env <- new.env()
  env$x <- 1:1000
  env$y <- letters
  result <- size_env(.envir = env)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("name", "size", "pretty"))
  expect_setequal(result$name, c("x", "y"))
})

test_that("size_env() returns rows in descending order of size", {
  env <- new.env()
  env$big   <- 1:1e5
  env$small <- 1:3
  result <- size_env(.envir = env)
  expect_equal(result$name[1], "big")
})

test_that("size_env(n = k) returns at most k rows", {
  env <- new.env()
  env$a <- 1:100
  env$b <- 1:200
  env$c <- 1:300
  result <- size_env(.envir = env, n = 2)
  expect_equal(nrow(result), 2)
})

test_that("size_env() returns NULL invisibly for empty environment", {
  env <- new.env()
  expect_null(size_env(.envir = env))
})
