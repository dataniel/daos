df <- data.frame(
  cvr  = c("1", "2", "1", "3"),
  year = c(2024, 2024, 2024, 2025)
)

test_that("expect_unique() passes on a unique key and returns data", {
  expect_message(expect_unique(df[-3, ], cvr), "Unique on cvr")
  expect_equal(expect_unique(df[-3, ], cvr), df[-3, ])
})

test_that("expect_unique() reports duplicated rows grouped by dupid", {
  cnd <- rlang::catch_cnd(expect_unique(df, cvr, year), classes = "daos_check_failure")
  expect_match(conditionMessage(cnd), "Duplicate rows on cvr, year")
  expect_equal(nrow(cnd$violations), 2)
  expect_true("dupid" %in% names(cnd$violations))
  expect_false("isdup" %in% names(cnd$violations))
  expect_match(conditionMessage(cnd), "2 rows in 1 group:")
})

test_that("expect_unique() puts dupid and the key columns first", {
  cnd <- rlang::catch_cnd(expect_unique(df, year, cvr), classes = "daos_check_failure")
  expect_equal(names(cnd$violations), c("dupid", "year", "cvr"))
})

test_that("expect_unique() without columns checks full rows", {
  expect_message(expect_unique(df[-3, ]), "Unique on all columns")
  expect_warning(expect_unique(df), "Duplicate rows on all columns")
})

test_that("expect_unique() aborts with abort_msg", {
  expect_error(expect_unique(df, cvr, abort_msg = "Dup cvr"), "Dup cvr")
})
