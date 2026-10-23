# "0101004007": born 01-01-2000, passes mod-11, sequential number 4007 (female)
# "111111-1118": born 11-11-1911, passes mod-11 (male)

test_that("add_cpr_info() appends bday correctly", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "bday")
  expect_true("bday" %in% names(result))
  expect_equal(result$bday, as.Date("2000-01-01"))
})

test_that("add_cpr_info() appends sex as 1/0", {
  df <- data.frame(pnr = c("0101004007", "111111-1118"), stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "sex")
  # "0101004007" d10=7 (odd) → 1; "111111-1118" d10=8 (even) → 0
  expect_equal(result$sex, c(1L, 0L))
})

test_that("add_cpr_info() appends mod11 correctly", {
  # "0101004007" passes mod-11 (sum=33); "0000000001" fails (sum=1)
  df <- data.frame(pnr = c("0101004007", "0000000001"), stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "mod11")
  expect_true(result$mod11[1])
  expect_false(result$mod11[2])
})

test_that("add_cpr_info() auto-pads 9-digit CPR numbers", {
  df <- data.frame(pnr = "101004007", stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "bday")
  expect_equal(result$bday, as.Date("2000-01-01"))
})

test_that("add_cpr_info() standardises CPR column to 10-digit format", {
  df <- data.frame(pnr = c("0101004007", "111111-1118", "101004007"), stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "valid")
  expect_equal(result$pnr, c("0101004007", "1111111118", "0101004007"))
})

test_that("add_cpr_info() marks invalid formats with valid = FALSE and NA dates", {
  df <- data.frame(pnr = c("notacpr", "0101004007"), stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = c("valid", "bday"))
  expect_false(result$valid[1])
  expect_true(result$valid[2])
  expect_true(is.na(result$bday[1]))
})

test_that("add_cpr_info() supports custom column names", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = c(birth_date = "bday", years = "age"),
                     ref_date = "2026-01-01")
  expect_true("birth_date" %in% names(result))
  expect_true("years" %in% names(result))
  expect_false("bday" %in% names(result))
})

test_that("add_cpr_info() respects ref_date for age calculation", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  result <- add_cpr_info(df, pnr, add = "age", ref_date = "2030-06-01")
  expect_equal(result$age, 30L)
})

test_that("add_cpr_info() aborts on unknown info type", {
  df <- data.frame(pnr = "0101004007", stringsAsFactors = FALSE)
  expect_error(add_cpr_info(df, pnr, add = "birthday"), class = "rlang_error")
})

test_that("reference date vectors calculate ages row by row", {
  df <- data.frame(pnr = rep("1111111118", 3))
  dates <- c("2025-11-10", "2025-11-11", "2026-01-01")
  for (ref in list(dates, as.Date(dates))) {
    expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = ref)$age,
                     c(113L, 114L, 114L))
  }
})

test_that("reference dates can use columns and expressions in data", {
  df <- data.frame(pnr = rep("0101004007", 3), year = 2024:2026)
  df$primo <- as.Date(paste0(df$year, "-01-01"))
  primo <- as.Date("1900-01-01") # The data column takes precedence.
  expect_identical(
    add_cpr_info(df, pnr, add = c(primoalder = "age"), ref_date = primo)$primoalder,
    24:26
  )
  expect_identical(
    add_cpr_info(df, pnr, add = "age",
                 ref_date = as.Date(paste0(year, "-01-01")))$age,
    24:26
  )
  df$primo <- as.character(df$primo)
  expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = primo)$age, 24:26)
})

test_that("missing reference dates propagate to age", {
  df <- data.frame(pnr = c("0101004007", "0101004007", "invalid"))
  dates <- c(NA_character_, "2025-01-01", "2025-01-01")
  for (ref in list(dates, as.Date(dates))) {
    expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = ref)$age,
                     c(NA_integer_, 25L, NA_integer_))
  }
})

test_that("reference dates reject incompatible lengths and malformed dates", {
  df <- data.frame(pnr = rep("0101004007", 4))
  for (ref in list(character(), rep("2025-01-01", 2), rep("2025-01-01", 5))) {
    expect_error(add_cpr_info(df, pnr, ref_date = ref), "must have length 1")
  }
  for (ref in list("bad", c("2025-01-01", "bad", NA, "2025-01-01"))) {
    expect_error(add_cpr_info(df, pnr, ref_date = ref), "could not be parsed")
  }
  expect_error(add_cpr_info(df, pnr, ref_date = TRUE), "must be a string")
})

test_that("numeric years mean January 1 for scalar and row-wise ages", {
  df <- data.frame(pnr = c("0101004007", "1111111118", "0101004007"),
                   year = c(2024L, 2025L, NA_integer_))
  expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = year)$age,
                   c(24L, 113L, NA_integer_))
  expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = 2025)$age,
                   c(25L, 113L, 25L))
  years <- c(2024, 2025, NA_real_)
  expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = years)$age,
                   c(24L, 113L, NA_integer_))
  for (ref in c(2025.5, Inf, -Inf, 0, 10000)) {
    expect_error(add_cpr_info(df, pnr, ref_date = ref), "whole years")
  }
})

test_that("leap-day birthdays advance on February 29 or March 1", {
  dates <- c("2024-02-28", "2024-02-29", "2024-03-01",
             "2025-02-28", "2025-03-01", "2100-02-28", "2100-03-01")
  expected <- c(23L, 24L, 24L, 24L, 25L, 99L, 100L)
  df <- data.frame(pnr = rep("2902004007", length(dates)), ref = dates)
  # Character and Date columns must follow the same rule. 2100 is not a leap year.
  for (refs in list(dates, as.Date(dates))) {
    df$ref <- refs
    expect_identical(add_cpr_info(df, pnr, add = "age", ref_date = ref)$age,
                     expected)
  }
  for (i in seq_along(dates)) {
    expect_identical(
      add_cpr_info(df[1L, ], pnr, add = "age", ref_date = dates[i])$age,
      expected[i])
  }
  expect_identical(add_cpr_info(df[1L, ], pnr, add = "age", ref_date = 2024)$age,
                   23L)
  expect_identical(add_cpr_info(df[1L, ], pnr, add = "age", year = 2024)$age,
                   23L)
})

test_that("reference date columns support empty data", {
  df <- data.frame(pnr = character(), primo = as.Date(character()))
  expect_identical(add_cpr_info(df, pnr, ref_date = primo)$age, integer())
  expect_identical(add_cpr_info(df, pnr)$age, integer())
})

test_that("add_cpr_info() aborts when column does not exist", {
  df <- data.frame(x = "0101004007", stringsAsFactors = FALSE)
  expect_error(add_cpr_info(df, missing_col), class = "rlang_error")
})

test_that("year positions include birthdays on their reference date", {
  df <- data.frame(pnr = c("0101004007", "3006004007", "0107004007",
                           "0207004007", "3112004007", "2902004007"),
                   yr = rep(2025L, 6))
  expected <- list(primo = c(25L, rep(24L, 5)),
                   medio = c(25L, 25L, 25L, 24L, 24L, 25L),
                   ultimo = rep(25L, 6))
  for (position in names(expected)) {
    expect_identical(
      add_cpr_info(df, pnr, add = "age", year = yr, at = position)$age,
      expected[[position]])
    expect_identical(
      add_cpr_info(df, pnr, add = "age", ref_date = 2025, at = position)$age,
      expected[[position]])
  }
  df$yr <- c(2024L, 2025L, NA_integer_, 2026L, 2027L, 2028L)
  expect_identical(add_cpr_info(df, pnr, add = "age", year = yr, at = "ultimo")$age,
                   c(24L, 25L, NA_integer_, 26L, 27L, 28L))
  expect_error(add_cpr_info(df, pnr, year = yr, ref_date = 2025), "only one")
  expect_error(add_cpr_info(df, pnr, year = "2025"), "numeric whole years")
  expect_error(add_cpr_info(df, pnr, year = yr, at = "bad"), "arg")
  expect_error(add_cpr_info(df, pnr, ref_date = "2025-01-01", at = "medio"),
               "only supported")
})

test_that("individual outputs match combined outputs and ignore unused references", {
  df <- data.frame(pnr = c("0101004007", "1111111118", "2902004007",
                           "3102004007", "0000000001", "bad", NA_character_))
  all <- add_cpr_info(df, pnr, ref_date = "2025-07-01")
  for (type in c("bday", "age", "sex", "mod11", "valid")) {
    expect_identical(add_cpr_info(df, pnr, add = type,
                                  ref_date = "2025-07-01")[[type]], all[[type]])
    if (type != "age") {
      expect_identical(add_cpr_info(df, pnr, add = type,
                                    ref_date = stop("unused"), year = stop("unused"),
                                    at = stop("unused"))[[type]], all[[type]])
    }
  }
  expect_identical(add_cpr_info(df, pnr, add = character())$pnr, clean_cpr(df$pnr))
  empty <- data.frame(pnr = character(), yr = integer())
  expect_identical(add_cpr_info(empty, pnr, year = yr, at = "medio")$age, integer())
})
