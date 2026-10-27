df <- data.frame(id = c(1, NA, 3), amount = c(10, -5, NA))

test_that("expect_none() returns the full data, not the violations", {
  out <- suppressWarnings(expect_none(df, amount < 0))
  expect_equal(out, df)
  expect_invisible(expect_none(df, amount > 100))
})

test_that("expect_none() can be chained in a pipeline", {
  out <- df |>
    expect_none(amount > 100) |>
    expect_none(id > 10)
  expect_equal(out, df)
})

test_that("expect_none() derives messages from the condition", {
  expect_message(expect_none(df, amount > 100), "No rows where amount > 100")
  expect_warning(expect_none(df, amount < 0), "Found rows where amount < 0")
})

test_that("user messages and abort work as in expect_empty()", {
  expect_message(expect_none(df, amount > 100, warn_msg = "Big"), "Check passed: Big")
  expect_error(expect_none(df, is.na(id), abort_msg = "NA ids"), "NA ids",
               class = "daos_check_failure")
})

test_that("NA in a condition is not a violation, as in filter()", {
  expect_no_warning(expect_none(df, amount > 50))
})

test_that("several conditions are combined with &", {
  cnd <- rlang::catch_cnd(expect_none(df, amount < 20, id > 0),
                          classes = "daos_check_failure")
  expect_equal(nrow(cnd$violations), 1)
  expect_match(conditionMessage(cnd), "amount < 20 & id > 0", fixed = TRUE)
})

test_that("expect_none() requires a condition and a data frame", {
  expect_error(expect_none(df), "at least one condition")
  expect_error(expect_none(list(), x > 1), "must be a data frame")
})

test_that("errors name expect_none() as the caller", {
  cnd <- rlang::catch_cnd(expect_none(df, is.na(id), abort_msg = "NA ids"))
  expect_equal(rlang::call_name(cnd$call), "expect_none")
})
