test_that("clean_cpr() strips dashes and spaces", {
  expect_equal(clean_cpr("111111-1118"), "1111111118")
  expect_equal(clean_cpr("111111 1118"), "1111111118")
})

test_that("clean_cpr() zero-pads nine-digit values", {
  expect_equal(clean_cpr("101004007"), "0101004007")
  expect_equal(clean_cpr("101004-007"), "0101004007")
})

test_that("clean_cpr() leaves malformed values cleaned but unpadded", {
  expect_equal(clean_cpr("notacpr"), "notacpr")
  expect_equal(clean_cpr("12345678"), "12345678")
  expect_equal(clean_cpr("12345678a"), "12345678a")
})

test_that("clean_cpr() coerces numeric input", {
  expect_equal(clean_cpr(1111111118), "1111111118")
  expect_equal(clean_cpr(101004007), "0101004007")
})

test_that("clean_cpr() preserves NA", {
  expect_equal(clean_cpr(c(NA, "111111-1118")), c(NA, "1111111118"))
})

test_that("clean_cpr() matches the cleaning inside add_cpr_info()", {
  raw <- c("0101004007", "111111-1118", "101004007", "notacpr")
  df  <- data.frame(pnr = raw, stringsAsFactors = FALSE)
  expect_identical(add_cpr_info(df, pnr, valid)$pnr, raw)
  cleaned <- data.frame(pnr = clean_cpr(raw))
  expect_identical(add_cpr_info(df, pnr, bday)$bday,
                   add_cpr_info(cleaned, pnr, bday)$bday)
})


test_that("cleaning and direct derivation share one normalisation contract", {
  x <- c("0101004007", "010100-4007", " 010100 4007 ", "101004007",
         "1-0 1004007", "", "- -", "not-a cpr", "12345678", "12345678901",
         "010100400x", "0101004007\t", NA_character_, "\u00e6 - ",
         "\uff10\uff11\uff10\uff11\uff10\uff10\uff14\uff10\uff10\uff17")
  cleaned <- clean_cpr(x)
  expect_identical(clean_cpr(cleaned), cleaned)
  direct <- add_cpr_info(data.frame(pnr = x), pnr,
                        bday, sex, valid, mod11, age(2025))
  explicit <- add_cpr_info(data.frame(pnr = cleaned), pnr,
                          bday, sex, valid, mod11, age(2025))
  expect_identical(direct[-1], explicit[-1])
  expect_identical(direct$pnr, x)
  expect_identical(cleaned[1:5], rep("0101004007", 5))
  expect_identical(cleaned[6:10], c("", "", "notacpr", "12345678", "12345678901"))
  expect_identical(cleaned[14], "\u00e6")
  expect_false(direct$valid[15])
  expect_identical(clean_cpr(c(a = "101004007", b = NA)), c(a = "0101004007", b = NA_character_))
  expect_identical(clean_cpr(factor(c("101004007", "0101004007"))), rep("0101004007", 2))
})


test_that("native cleaning matches the original R contract on varied input", {
  reference <- function(x) {
    if (!is.character(x)) x <- as.character(x)
    x <- gsub("[- ]", "", x)
    pad <- !is.na(x) & grepl("^\\d{9}$", x)
    x[pad] <- paste0("0", x[pad])
    x
  }
  set.seed(912)
  random <- replicate(1000, paste0(sample(c(0:9, "-", " ", "x"), sample(0:15, 1), replace = TRUE), collapse = ""))
  samples <- list(random, character(), c(NA_character_, "-", "101004007"),
    setNames(c("101004007", "111111-1118"), c("a", "b")),
    matrix(c("101004007", "111111-1118"), nrow = 1),
    structure(c("101004007", "111111-1118"), class = "AsIs"),
    factor(c("101004007", "111111-1118")), c(101004007, NA, 1111111118))
  for (x in samples) expect_identical(clean_cpr(x), reference(x))
})
