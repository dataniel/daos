test_that("labels use DST titles and recognise mixed formatting", {
  for (version in c("DB07", "DB25")) {
    expect_equal(db_label(c("011200", "01.12.00", "01 12 00", "01\t12\n00"), version),
                 rep("Dyrkning af ris", 4))
  }
  expect_equal(db_label("014910", "DB07"), "Kenneler")
  expect_equal(db_label("014800", "DB25"), "Avl af andre dyr")
  expect_false(identical(db_label("253000", "DB07"), db_label("253000", "DB25")))
})

test_that("labels support all hierarchy levels and preserve Danish text", {
  for (version in c("DB07", "DB25")) {
    labels <- db_label(c("A", "01", "01.1", "01.11", "01.11.00"), version)
    expect_length(labels, 5L)
    expect_false(anyNA(labels))
    expect_identical(labels[3], "Dyrkning af et\u00e5rige afgr\u00f8der")
    expect_identical(labels[4], labels[5])
  }
})

test_that("unknown and malformed codes warn but missing and empty vectors do not", {
  for (version in c("DB07", "DB25")) {
    expect_warning(out <- db_label(c("999999", "11100", "1", "", "a", "01120x", NA), version),
                   "6 invalid or unknown")
    expect_identical(out, rep(NA_character_, 7))
    expect_no_warning(expect_identical(db_label(c(NA, NA), version), rep(NA_character_, 2)))
    expect_identical(db_label(character(), version), character())
    expect_equal(db_label(factor(c("011200", "011200")), version), rep("Dyrkning af ris", 2))
    expect_identical(db_label(10, version), db_label("10", version))
  }
  expect_error(db_label("011200", version = "DB03"), "'arg'")
})

test_that("bundled labels cover all conversion keys and have unique codes", {
  for (version in c("DB07", "DB25")) {
    labels <- if (version == "DB07") db07_labels else db25_labels
    key <- if (version == "DB07") db07_db25_key else db25_db07_key
    expect_identical(anyDuplicated(names(labels)), 0L)
    expect_false(anyNA(labels))
    expect_true(all(nzchar(labels)))
    expect_setequal(names(labels)[nchar(names(labels)) == 6L], names(key))
    expect_identical(db_label(names(labels), version), unname(labels))
  }
})

test_that("classification must be selected explicitly", {
  expect_error(db_label("011200"), "Choose version")
  expect_error(db_label("011200", version = NULL), "Choose version")
  expect_error(db_label("011200", version = "auto"), "'arg'")
  expect_warning(out <- db_label("014910", version = "DB25"), "unknown DB25")
  expect_identical(out, NA_character_)
  expect_warning(out <- db_label("014800", version = "DB07"), "unknown DB07")
  expect_identical(out, NA_character_)
})
