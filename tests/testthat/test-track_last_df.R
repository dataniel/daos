test_that("track_last_df() returns TRUE invisibly when enabling", {
  result <- track_last_df()
  expect_true(result)
  track_last_df(FALSE)
})

test_that("track_last_df() returns TRUE invisibly when disabling", {
  result <- track_last_df(FALSE)
  expect_true(result)
})

test_that("track_last_df() installs a callback when enabled", {
  track_last_df(name = ".test_df")
  on.exit(track_last_df(FALSE))
  expect_true("track_last_df" %in% getTaskCallbackNames())
})

test_that("track_last_df() removes the callback when disabled", {
  track_last_df()
  track_last_df(FALSE)
  expect_false("track_last_df" %in% getTaskCallbackNames())
})
