make_ta2_line <- function(nrnr = "123456", trans = "0100", brch = "", bas = "100",
                          eng = "50", det = "30", afg = "10", moms = "", kbx = "2") {
  paste0(
    formatC(nrnr, width = 6, flag = "-"), strrep(" ", 10),
    formatC(trans, width = 5, flag = "-"), strrep(" ", 9),
    formatC(brch, width = 5, flag = "-"),
    formatC(bas, width = 25),
    paste(formatC(c(eng, det, afg, moms, kbx), width = 16), collapse = "")
  )
}

test_that("read_ta2() reads the nine columns with the right types", {
  path <- withr::local_tempfile()
  writeLines(make_ta2_line(), path)

  result <- read_ta2(path)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("nrnr", "trans", "brch", "bas", "eng", "det",
                         "afg", "moms", "kbx"))
  expect_identical(result$nrnr, "123456")
  expect_identical(result$trans, "0100")
  expect_identical(result$bas, 100)
  expect_identical(result$kbx, 2)
})

test_that("read_ta2() reads blank fields as NA", {
  path <- withr::local_tempfile()
  writeLines(make_ta2_line(), path)

  result <- read_ta2(path)
  expect_identical(result$brch, NA_character_)
  expect_identical(result$moms, NA_real_)
})

test_that("read_ta2() rejects short lines, pointing to read_ta()", {
  path <- withr::local_tempfile()
  writeLines(c(make_ta2_line(), "too short", make_ta2_line(), "x"), path)
  expect_snapshot(read_ta2(path), error = TRUE)
})

test_that("read_ta2() errors on numeric fields that are not numbers", {
  path <- withr::local_tempfile()
  writeLines(c(make_ta2_line(), make_ta2_line(eng = "1.2.3", kbx = "abc")), path)
  expect_snapshot(read_ta2(path), error = TRUE)
})
