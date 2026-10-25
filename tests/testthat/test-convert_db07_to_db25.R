test_that("DST conversions handle unchanged and renumbered codes in both directions", {
  expect_equal(convert_db07_to_db25(c("011100", "01.49.10", "25 40 00", NA)),
               c("01.11.00", "01.48.00", "25.30.00", NA))
  expect_equal(convert_db25_to_db07(c("011100", "25.30.00", NA), "compact"),
               c("011100", "254000", NA))
})

test_that("strict conversion reports splits instead of taking the first match", {
  expect_warning(out <- convert_db07_to_db25(c("011900", "011100")),
                 "multiple DB25")
  expect_equal(out, c(NA_character_, "01.11.00"))
  expect_warning(out <- convert_db25_to_db07("014800"), "multiple DB07")
  expect_identical(out, NA_character_)
  expect_equal(convert_db07_to_db25("011900", "compact", "simple"), "011900")
})

test_that("invalid and unknown full codes are distinguished from missing input", {
  for (convert in list(convert_db07_to_db25, convert_db25_to_db07)) {
    for (method in c("strict", "simple")) {
      expect_warning(out <- convert(c("01", "011", "0111", "11100", "999999",
                                      "A", "01110x", "", NA), method = method),
                     "8 invalid or unknown")
      expect_identical(out, rep(NA_character_, 9))
      expect_no_warning(expect_identical(convert(NA_character_, method = method), NA_character_))
      expect_identical(convert(character(), method = method), character())
    }
    expect_equal(convert(factor("01.11.00")), "01.11.00")
    expect_warning(out <- convert(11100, "compact"), "invalid or unknown")
    expect_identical(out, NA_character_)
    expect_error(convert("011100", format = "unknown"), "'arg'")
    expect_error(convert("011100", method = "unknown"), "'arg'")
  }
})

test_that("bundled keys cover all source codes with valid destinations", {
  for (direction in c("forward", "reverse")) {
    if (direction == "forward") {
      key <- db07_db25_key
      simple <- db07_db25_simple
      convert <- convert_db07_to_db25
    } else {
      key <- db25_db07_key
      simple <- db25_db07_simple
      convert <- convert_db25_to_db07
    }
    expect_true(all(grepl("^[0-9]{6}$", names(key))))
    expect_true(all(grepl("^[0-9]{6}$", unlist(key))))
    expect_setequal(names(key), names(simple))
    expect_false(anyDuplicated(names(simple)) > 0L)
    expect_true(all(vapply(names(key), function(code) simple[[code]] %in% key[[code]], logical(1))))
    expect_equal(convert(names(simple), "compact", "simple"), unname(simple))
    unique <- lengths(key) == 1L
    expect_equal(convert(names(key)[unique], "compact"), unname(unlist(key[unique])))
  }
  forward_pairs <- sort(paste(rep(names(db07_db25_key), lengths(db07_db25_key)),
                             unlist(db07_db25_key)))
  reverse_pairs <- sort(paste(unlist(db25_db07_key),
                             rep(names(db25_db07_key), lengths(db25_db07_key))))
  expect_identical(forward_pairs, reverse_pairs)
})

test_that("reverse simple conversion uses its own DST key", {
  # A merge cannot be reversed by matching the first forward destination.
  codes <- names(db25_db07_simple)
  expect_equal(convert_db25_to_db07(codes, "compact", "simple"),
               unname(db25_db07_simple[codes]))
  x <- c("25.30.00", "01\t11\n00", "25.30.00")
  expect_equal(convert_db25_to_db07(x, "compact"), c("254000", "011100", "254000"))
})
