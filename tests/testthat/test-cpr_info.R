# "0101004007": born 01-01-2000, passes mod-11, sequential number 4007 (female)
# "111111-1118": born 11-11-1911, passes mod-11 (male)

test_that("cpr_info() appends bday correctly", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = "bday")
  expect_true("bday" %in% names(result))
  expect_equal(result$bday, as.Date("2000-01-01"))
})

test_that("cpr_info() appends sex correctly", {
  df <- data.frame(pnr = c("0101004007", "111111-1118"), stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = "sex")
  # "0101004007" d10=7 (odd) → mand; "111111-1118" d10=8 (even) → kvinde
  expect_equal(result$sex, c("mand", "kvinde"))
})

test_that("cpr_info() appends mod11 correctly", {
  # "0101004007" passes mod-11 (sum=33); "0000000001" fails (sum=1)
  df <- data.frame(pnr = c("0101004007", "0000000001"), stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = "mod11")
  expect_true(result$mod11[1])
  expect_false(result$mod11[2])
})

test_that("cpr_info() auto-pads 9-digit CPR numbers", {
  df <- data.frame(pnr = "101004007", stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = "bday")
  expect_equal(result$bday, as.Date("2000-01-01"))
})

test_that("cpr_info() marks invalid formats with valid = FALSE and NA dates", {
  df <- data.frame(pnr = c("notacpr", "0101004007"), stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = c("valid", "bday"))
  expect_false(result$valid[1])
  expect_true(result$valid[2])
  expect_true(is.na(result$bday[1]))
})

test_that("cpr_info() supports custom column names", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = c(birth_date = "bday", years = "age"),
                     ref_date = "2026-01-01")
  expect_true("birth_date" %in% names(result))
  expect_true("years" %in% names(result))
  expect_false("bday" %in% names(result))
})

test_that("cpr_info() respects ref_date for age calculation", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- cpr_info(df, pnr, add = "age", ref_date = "2030-06-01")
  expect_equal(result$age, 30L)
})

test_that("cpr_info() aborts on unknown info type", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  expect_error(cpr_info(df, pnr, add = "birthday"), class = "rlang_error")
})

test_that("cpr_info() aborts when column does not exist", {
  df <- data.frame(x = "0101004007", stringsAsFactors = FALSE)
  expect_error(cpr_info(df, missing_col), class = "rlang_error")
})
