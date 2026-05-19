test_that("summon() retrieves matching objects", {
  env <- new.env()
  env$dat1 <- data.frame(x = 1)
  env$dat2 <- data.frame(x = 2)
  env$other <- "ignore"
  result <- summon("^dat\\d+$", .envir = env)
  expect_type(result, "list")
  expect_setequal(names(result), c("dat1", "dat2"))
})

test_that("summon() aborts when no objects match", {
  env <- new.env()
  expect_error(summon("^xyz$", .envir = env), class = "rlang_error")
})

test_that("summon() aborts on non-string pattern", {
  expect_error(summon(123),      class = "rlang_error")
  expect_error(summon(c("a", "b")), class = "rlang_error")
})
