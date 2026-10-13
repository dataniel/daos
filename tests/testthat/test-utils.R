test_that("format_elapsed() formats milliseconds", {
  expect_equal(format_elapsed(as.difftime(0.1, units = "secs")), "100ms")
  expect_equal(format_elapsed(as.difftime(0,   units = "secs")), "0ms")
})

test_that("format_elapsed() formats seconds", {
  expect_equal(format_elapsed(as.difftime(2.3, units = "secs")), "2.3s")
  expect_equal(format_elapsed(as.difftime(59,  units = "secs")), "59s")
})

test_that("format_elapsed() formats minutes", {
  expect_equal(format_elapsed(as.difftime(90, units = "secs")), "1.5m")
  expect_equal(format_elapsed(as.difftime(60, units = "secs")), "1m")
})
