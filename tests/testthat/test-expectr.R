df <- data.frame(id = c(1, 1, 2), amount = c(5, -1, 3))

test_that("the moved checkpoints forward to expectr with the same result", {
  rlang::local_options(rlib_message_verbosity = "quiet")
  expect_equal(expect_none(df, amount > 100), df)
  expect_equal(flag_duplicates(df, id), expectr::flag_duplicates(df, id))
  expect_equal(tally_violations(df, neg = amount < 0),
               expectr::tally_violations(df, neg = amount < 0))
  expect_equal(view_types(df, df), expectr::view_types(df, df))
})

test_that("tidy evaluation survives the forwarding", {
  rlang::local_options(rlib_message_verbosity = "quiet")
  cnd <- rlang::catch_cnd(expect_unique(df, id), classes = "expectr_failure")
  expect_equal(nrow(cnd$violations), 2)

  panel <- data.frame(cpr = c("a", "a", "b"), year = c(2020, 2021, 2021))
  cnd <- rlang::catch_cnd(expect_balanced(panel, cpr, year), classes = "expectr_failure")
  expect_equal(cnd$violations$year, 2020)
})

test_that("a failure still carries the old condition class", {
  rlang::local_options(rlib_message_verbosity = "quiet")
  w <- rlang::catch_cnd(expect_none(df, amount < 0), classes = "daos_check_failure")
  expect_s3_class(w, "warning")
  expect_s3_class(w, "expectr_failure")

  caught <- tryCatch(
    expect_none(df, amount < 0, abort_msg = "Negative"),
    daos_check_failure = function(e) e$violations
  )
  expect_equal(caught$amount, -1)
})

test_that("errors name the checkpoint, not the forwarding", {
  rlang::local_options(rlib_message_verbosity = "quiet")
  e <- rlang::catch_cnd(expect_none(df, amount < 0, abort_msg = "Negative"), classes = "error")
  expect_equal(rlang::call_name(conditionCall(e)), "expect_none")
})

test_that("the old option names are used when the new ones are not set", {
  rlang::local_options(rlib_message_verbosity = "quiet")
  log <- withr::local_tempfile(fileext = ".log")
  withr::local_options(daos.check_log = log, expectr.log = NULL)
  expect_none(df, amount > 100, warn_msg = "Old option")
  expect_match(readLines(log, encoding = "UTF-8"), "Old option")
})

test_that("the move is announced once", {
  rlang::reset_message_verbosity("daos_moved_to_expectr")
  expect_message(expect_none(df, amount > 100), "moved to the expectr package",
                 class = "daos_moved_to_expectr")
  expect_no_message(expect_none(df, amount > 100), class = "daos_moved_to_expectr")
})
