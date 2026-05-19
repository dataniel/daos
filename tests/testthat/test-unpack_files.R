test_that("unpack_files() assigns each list element to a variable", {
  env <- new.env()
  data <- list(a = data.frame(x = 1), b = data.frame(x = 2))
  unpack_files(data, .envir = env)
  expect_true(exists("a", envir = env))
  expect_true(exists("b", envir = env))
  expect_equal(env$a, data$a)
})

test_that("unpack_files() returns data invisibly", {
  env  <- new.env()
  data <- list(z = 99)
  result <- unpack_files(data, .envir = env)
  expect_equal(result, data)
})

test_that("unpack_files() aborts on conflict without .overwrite", {
  env   <- new.env()
  env$a <- "existing"
  expect_error(
    unpack_files(list(a = 1), .envir = env),
    class = "rlang_error"
  )
})

test_that("unpack_files(.overwrite = TRUE) overwrites existing variables", {
  env   <- new.env()
  env$a <- "old"
  unpack_files(list(a = "new"), .envir = env, .overwrite = TRUE)
  expect_equal(env$a, "new")
})

test_that("unpack_files() aborts on unnamed list", {
  expect_error(unpack_files(list(1, 2)), class = "rlang_error")
})

test_that("unpack_files() aborts on non-list input", {
  expect_error(unpack_files("text"), class = "rlang_error")
})
