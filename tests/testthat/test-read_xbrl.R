xbrl_fixture <- testthat::test_path("fixtures", "minimal.xml")

test_that("read_xbrl() returns a tibble", {
  result <- read_xbrl(xbrl_fixture)
  expect_s3_class(result, "tbl_df")
})

test_that("read_xbrl() returns one row per fact", {
  result <- read_xbrl(xbrl_fixture)
  expect_equal(nrow(result), 2)
})

test_that("read_xbrl() has expected columns", {
  result <- read_xbrl(xbrl_fixture)
  expect_named(result, c("unitid", "contextid", "elementid", "fact", "decimals",
                         "startdate", "enddate", "instant", "explicit_member", "unit"),
               ignore.order = TRUE)
})

test_that("read_xbrl() joins context dates correctly", {
  result <- read_xbrl(xbrl_fixture)
  revenue_row <- result[result$elementid == "Revenue", ]
  expect_equal(revenue_row$startdate, "2023-01-01")
  expect_equal(revenue_row$enddate,   "2023-12-31")
})

test_that("read_xbrl() joins unit correctly", {
  result <- read_xbrl(xbrl_fixture)
  expect_true(all(grepl("DKK", result$unit)))
})

test_that("read_xbrl() strips namespace prefixes from contextid and unitid", {
  result <- read_xbrl(xbrl_fixture)
  expect_false(any(grepl(":", result$contextid, fixed = TRUE)))
  expect_false(any(grepl(":", result$unitid[!is.na(result$unitid)], fixed = TRUE)))
})
