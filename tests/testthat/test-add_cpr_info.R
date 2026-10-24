test_that("selections preserve input, order, and output types", {
  df <- data.frame(pnr = c("0101004007", "111111-1118", "101004007"), year = 2025L)
  original <- df
  out <- add_cpr_info(df, pnr, sex, birth_date = bday, age(year))
  expect_identical(df, original)
  expect_identical(out$pnr, df$pnr)
  expect_named(out, c("pnr", "year", "sex", "birth_date", "age"))
  expect_identical(out$sex, c(1L, 0L, 1L))
  expect_identical(out$birth_date, as.Date(c("2000-01-01", "1911-11-11", "2000-01-01")))
  expect_identical(out$age, c(25L, 113L, 25L))
  expect_identical(add_cpr_info(df, "pnr", sex), add_cpr_info(df, pnr, sex))
  defaults <- add_cpr_info(df, pnr)
  expect_named(defaults, c(names(df), "bday", "age", "sex", "mod11", "valid"))
  expect_identical(defaults$age, add_cpr_info(df, pnr, age(date = Sys.Date()))$age)
  expect_identical(add_cpr_info(df, pnr, age)$age, defaults$age)
})

test_that("multiple reference years and positions work in one call", {
  df <- data.frame(pnr = c("0101004007", "3006004007", "0107004007",
                          "0207004007", "3112004007", "2902004007"), year = 2025L)
  out <- add_cpr_info(df, pnr, primo = age(year), medio = age(year, "medio"),
                     ultimo = age(year, "ultimo"))
  expect_identical(out$primo, c(25L, rep(24L, 5)))
  expect_identical(out$medio, c(25L, 25L, 25L, 24L, 24L, 25L))
  expect_identical(out$ultimo, rep(25L, 6))
  expect_identical(add_cpr_info(df, pnr, age(2025))$age, out$primo)
  expect_identical(add_cpr_info(df, pnr, age(year + 1L))$age, out$primo + 1L)
})

test_that("references use caller environments and explicit data pronouns", {
  df <- data.frame(pnr = c("0101004007", "0101004007"), year = 2024:2025,
                   date = c("2024-07-01", "2025-07-01"), ref = 1:2)
  year <- 2030L
  expect_identical(add_cpr_info(df, pnr, age(year))$age, 24:25)
  expect_identical(add_cpr_info(df, pnr, age(.env$year))$age, c(30L, 30L))
  expect_identical(add_cpr_info(df, pnr, age(.data$year))$age, 24:25)
  expect_identical(add_cpr_info(df, pnr, age(date = date))$age, 24:25)
  wrapper <- function(data, col, reference) {
    add_cpr_info(data, {{ col }}, alder = age({{ reference }}))
  }
  expect_identical(wrapper(df, pnr, year)$alder, 24:25)
  # Selection names are syntax, independent of columns/caller variables.
  sex <- "not a selector"
  df$sex <- 99L
  expect_identical(add_cpr_info(df, pnr, koen = sex)$koen, c(1L, 1L))
  expect_identical(add_cpr_info(df, pnr, age = age(year))$age, 24:25)
})

test_that("leap birthdays and missing references retain calendar semantics", {
  dates <- c("2024-02-28", "2024-02-29", "2024-03-01", "2025-02-28",
             "2025-03-01", "2100-02-28", "2100-03-01", NA_character_)
  df <- data.frame(pnr = rep("2902004007", length(dates)))
  expected <- c(23L, 24L, 24L, 24L, 25L, 99L, 100L, NA_integer_)
  expect_identical(add_cpr_info(df, pnr, age(date = dates))$age, expected)
  expect_identical(add_cpr_info(df, pnr, age(date = as.Date(dates)))$age, expected)
  df <- data.frame(pnr = rep("0101004007", 3), year = c(2024L, NA_integer_, 2026L))
  expect_identical(add_cpr_info(df, pnr, age(year))$age, c(24L, NA_integer_, 26L))
  expect_identical(add_cpr_info(df, pnr, age(date = "1999-12-31"))$age, rep(-1L, 3))
})

test_that("format, calendar validity, and checksum remain separate", {
  df <- data.frame(pnr = c("0101004007", "3102004007", "notacpr", NA, "0101004000"))
  out <- add_cpr_info(df, pnr, bday, sex, valid, mod11, age(2025))
  expect_identical(out$valid, c(TRUE, FALSE, FALSE, FALSE, TRUE))
  expect_true(all(is.na(out$bday[2:4])))
  expect_true(all(is.na(out$sex[2:4])))
  expect_true(all(is.na(out$age[2:4])))
  expect_true(out$mod11[1])
  expect_false(out$mod11[5])
  expect_true(all(is.na(out$mod11[3:4])))
  expect_identical(out$age[c(1, 5)], c(25L, 25L))
})

test_that("century boundaries remain correct", {
  df <- data.frame(pnr = c("0101364001", "0101374001", "0101575001",
                          "0101585001", "0101000001", "0101009001"))
  expect_identical(add_cpr_info(df, pnr, bday)$bday,
    as.Date(c("2036-01-01", "1937-01-01", "2057-01-01", "1858-01-01", "1900-01-01", "2000-01-01")))
})

test_that("collisions require explicit consent and never rename input columns", {
  df <- data.frame(pnr = "0101004007", age = 99L, year = 2025L)
  expect_error(add_cpr_info(df, pnr, age(year)), "overwrite = TRUE")
  expect_identical(add_cpr_info(df, pnr, age(year), overwrite = TRUE)$age, 25L)
  expect_identical(df$age, 99L)
  expect_error(add_cpr_info(df, pnr, age(year), age(2026)), "Duplicate output")
  expect_error(add_cpr_info(df, pnr, x = sex, x = bday), "Duplicate output")
  expect_error(add_cpr_info(df, pnr, pnr = sex, overwrite = TRUE), "source column")
  # All calculations see original columns, including columns being overwritten.
  out <- add_cpr_info(df, pnr, year = age(year), second = age(year), overwrite = TRUE)
  expect_identical(out$year, 25L)
  expect_identical(out$second, 25L)
  expect_error(add_cpr_info(df, pnr, sex, overwrite = NA), "TRUE or FALSE")
})

test_that("invalid selections and old API calls have actionable errors", {
  df <- data.frame(pnr = "0101004007")
  expect_error(add_cpr_info(df, absent, sex), "not found")
  expect_error(add_cpr_info(df, pnr, birthday), "Unknown CPR selection")
  expect_error(add_cpr_info(df, pnr, age = list(2025, "primo")), "Unknown CPR selection")
  expect_error(add_cpr_info(df, pnr, add = "age", ref_date = 2025), "API has changed")
  expect_error(add_cpr_info(df, pnr, sex()), "Unknown CPR selection")
  expect_error(add_cpr_info(df, pnr, ), "Empty CPR selection")
  expect_error(add_cpr_info(NULL, pnr), "data frame")
  expect_error(add_cpr_info(df, paste0("p", "nr")), "column name")
  bad <- df; names(bad) <- ""
  expect_error(add_cpr_info(bad, pnr), "column names")
})

test_that("reference arguments are validated with useful errors", {
  df <- data.frame(pnr = rep("0101004007", 3))
  expect_error(add_cpr_info(df, pnr, age(2025, date = "2025-01-01")), "only one")
  expect_error(add_cpr_info(df, pnr, age(date = "2025-01-01", at = "primo")), "only supported")
  expect_error(add_cpr_info(df, pnr, age(2025, "bad")), "at")
  expect_error(add_cpr_info(df, pnr, age(missing_year)), "age reference")
  for (x in list("2025", 2025.5, Inf, 0, 10000, TRUE, as.Date("2025-01-01"))) {
    expect_error(add_cpr_info(df, pnr, age(x)), "numeric whole years")
  }
  for (x in list(2024:2025, integer(), 2024:2027)) {
    expect_error(add_cpr_info(df, pnr, age(x)), "length 1")
  }
  for (x in c("bad", "2025-02-29", "2025-01-01junk", "2025-1-1")) {
    expect_error(add_cpr_info(df, pnr, age(date = x)), "ISO dates")
  }
  expect_error(add_cpr_info(df, pnr, age(date = 2025)), "Date vector")
})

test_that("empty frames, tibble grouping, and data tables retain structure", {
  empty <- data.frame(pnr = character(), year = integer())
  expect_identical(add_cpr_info(empty, pnr, age(year))$age, integer())
  expect_identical(add_cpr_info(empty, pnr)$bday, as.Date(character()))
  df <- tibble::tibble(pnr = c("0101004007", "1111111118"), g = 1:2)
  grouped <- dplyr::group_by(df, g)
  result <- add_cpr_info(grouped, pnr, sex)
  expect_s3_class(result, "grouped_df")
  expect_identical(dplyr::group_vars(result), "g")
  expect_identical(result$pnr, df$pnr)
  dt <- data.table::as.data.table(df)
  copy <- data.table::copy(dt)
  result <- add_cpr_info(dt, pnr, sex)
  expect_s3_class(result, "data.table")
  expect_identical(dt, copy)
  expect_identical(result$sex, c(1L, 0L))
})


test_that("qualified age helper and tidy injection work", {
  df <- data.frame(pnr = "0101004007", year = 2025L)
  expect_identical(add_cpr_info(df, pnr, daos::age(year))$age, 25L)
  selections <- rlang::quos(alder = age(year), sex)
  expect_named(add_cpr_info(df, pnr, !!!selections), c("pnr", "year", "alder", "sex"))
})


test_that("native date arithmetic agrees with calendar dates over centuries", {
  set.seed(718)
  birth <- as.Date("1800-01-01") + sample.int(90000L, 3000L, replace = TRUE)
  y <- as.integer(format(birth, "%Y"))
  # Only representable years for century digit 5 (1858-1899, 2000-2057).
  keep <- (y >= 1858 & y <= 1899) | (y >= 2000 & y <= 2046)
  birth <- birth[keep]
  pnr <- paste0(format(birth, "%d%m%y"), "5001")
  reference <- as.Date("1700-01-01") + sample.int(180000L, length(birth), replace = TRUE)
  expected <- as.integer(as.integer(format(reference, "%Y")) - as.integer(format(birth, "%Y")) -
    (format(reference, "%m%d") < format(birth, "%m%d")))
  df <- data.frame(pnr = pnr, reference = reference)
  result <- add_cpr_info(df, pnr, bday, age(date = reference))
  expect_identical(result$bday, birth)
  expect_identical(result$age, expected)
  expect_identical(add_cpr_info(df, pnr, age(date = as.character(reference)))$age, expected)
  fractional <- as.Date(-0.5, origin = "1970-01-01")
  expect_identical(add_cpr_info(df, pnr, age(date = fractional))$age,
                   add_cpr_info(df, pnr, age(date = "1969-12-31"))$age)
  bad <- data.frame(pnr = "invalid")
  expect_error(add_cpr_info(bad, pnr, age(date = "2025-02-29")), "ISO dates")
  empty <- data.frame(pnr = character())
  expect_error(add_cpr_info(empty, pnr, age(date = "2025-02-29")), "ISO dates")
})
