make_ta_line <- function(nrnr  = "123456",
                         trans = "1234567",
                         brch  = "12345",
                         bas   = "   100.00      ",
                         eng   = "    50.00    ",
                         det   = "    30.00    ",
                         afg   = "    10.00    ",
                         moms  = "     5.00    ",
                         kbx   = "     2.00    ",
                         prim  = "  1.00",
                         afstm = "2024",
                         fval  = "DKK") {
  paste0(nrnr, trans, brch, bas, eng, det, afg, moms, kbx, prim, afstm, fval)
}

test_that("read_ta() reads a TA file and returns expected columns", {
  path <- withr::local_tempfile()
  writeLines(make_ta_line(), path)

  result <- read_ta(path)
  expect_s3_class(result, "data.frame")
  expected_cols <- c("nrnr", "trans", "brch", "bas", "eng", "det",
                     "afg", "moms", "kbx", "prim", "afstm", "fval")
  expect_named(result, expected_cols)
})

test_that("read_ta() returns character columns for nrnr, trans, brch, afstm, fval", {
  path <- withr::local_tempfile()
  writeLines(make_ta_line(), path)

  result <- read_ta(path)
  expect_type(result$nrnr,  "character")
  expect_type(result$trans, "character")
  expect_type(result$brch,  "character")
  expect_type(result$afstm, "character")
  expect_type(result$fval,  "character")
})

test_that("read_ta() returns numeric columns for numeric fields", {
  path <- withr::local_tempfile()
  writeLines(make_ta_line(), path)

  result <- read_ta(path)
  expect_type(result$bas, "double")
  expect_type(result$eng, "double")
})
