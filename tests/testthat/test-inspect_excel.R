test_that("inspect_excel() finds the blocks around the main table", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("readxl")
  skip_if_not_installed("xml2")
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- inspect_excel(path)
  expect_s3_class(res, "tbl_df")
  expect_equal(res$sheet, rep("Report", 3))
  expect_equal(res$area, rep("B3:C6", 3))
  expect_equal(res$block, c("A1", "F4", "B9"))
  expect_equal(res$position, c("title", "right", "below"))
  expect_equal(res$first, c("Table 3: Employed 2024", "note", "Source: DST"))
})

test_that("inspect_excel() returns an empty tibble for a clean sheet", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("readxl")
  skip_if_not_installed("xml2")
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- inspect_excel(path, sheet = "Clean")
  expect_equal(nrow(res), 0)
  expect_named(res, c("sheet", "area", "block", "position", "cells", "first"))
})

test_that("inspect_excel() reports cells outside a range, and skip drops the top rows", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("readxl")
  skip_if_not_installed("xml2")
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- inspect_excel(path, range = "Report!B3:C5")
  expect_equal(res$block, c("A1", "F4", "B6:C6", "B9"))
  expect_equal(res$position, c("title", "right", "below", "below"))
  expect_equal(res$cells[3], 2)
  expect_false("A1" %in% inspect_excel(path, sheet = "Report", skip = 1)$block)
})

test_that("inspect_excel() relates blocks to defined tables", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("readxl")
  skip_if_not_installed("xml2")
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- inspect_excel(path, table = TRUE)
  expect_match(res$area, "^\\w+ \\(B3:C6\\)$")
  expect_equal(res$block, c("A1", "F4", "B9"))
})

test_that("inspect_excel() splits blocks at empty rows and columns only", {
  # A 2x2 block, then two empty rows, then a band whose cells in columns 1
  # and 3 are split by the empty column 2.
  blocks <- daos:::.xy_blocks(r = c(1, 1, 2, 2, 5, 6, 6), c = c(1, 2, 1, 2, 1, 1, 3))
  expect_length(blocks, 3)
  expect_equal(sort(lengths(blocks)), c(1, 2, 4))
})

test_that("inspect_excel() converts between cell references and positions", {
  rc <- daos:::.ref_rc(c("A1", "$Z$9", "AA10", "XFD1048576"))
  expect_equal(rc$col, c(1, 26, 27, 16384))
  expect_equal(rc$row, c(1, 9, 10, 1048576))
  expect_equal(daos:::.col_letters(c(1, 26, 27, 16384)), c("A", "Z", "AA", "XFD"))
})

test_that("inspect_excel() and read_workbook() handle .xls files", {
  skip_if_not_installed("readxl")
  path <- readxl::readxl_example("datasets.xls")
  expect_equal(nrow(inspect_excel(path)), 0)
  res <- read_workbook(path)
  expect_equal(names(res), readxl::excel_sheets(path))
  expect_equal(res[[1]], readxl::read_excel(path, sheet = 1))
})
