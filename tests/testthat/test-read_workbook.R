skip_if_not_installed("openxlsx2")
skip_if_not_installed("readxl")
skip_if_not_installed("xml2")

test_that("read_workbook() reads the table found on every sheet into a named list", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- suppressWarnings(read_workbook(path))
  expect_type(res, "list")
  expect_named(res, c("Report", "Clean"))
  expect_equal(names(res$Report), c("a", "b"))   # not the title, not ...7
  expect_equal(res$Report$b, c("x", "y", "z"))   # not the source note
  expect_equal(res$Clean$q, 1:2)
})

test_that("read_workbook() leaves out a title with no empty row below it", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx2::wb_workbook()$add_worksheet("S")$
    add_data(x = "Table 1", dims = "A1")$
    add_data(x = "Unit: persons", dims = "A2")$
    add_data(x = data.frame(a = 1:2, b = 3:4), dims = "A3")$
    save(path)
  expect_no_warning(res <- read_workbook(path, sheet = "S"))
  expect_equal(names(res), c("a", "b"))
  title <- inspect_excel(path)
  expect_equal(title$block, "A1:A2")
  expect_equal(title$position, "title")
})

test_that("read_workbook() takes one range per sheet, NA meaning find it", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- suppressWarnings(read_workbook(path, range = c(Report = "B3:B6", Clean = NA)))
  expect_named(res, c("Report", "Clean"))
  expect_equal(names(res$Report), "a")
  expect_equal(res$Clean$q, 1:2)
  # sheets not named are found automatically
  res <- suppressWarnings(read_workbook(path, range = c(Clean = "A1:A2")))
  expect_equal(names(res$Report), c("a", "b"))
  expect_equal(nrow(res$Clean), 1)
})

test_that("read_workbook() returns a tibble for one named sheet", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  expect_silent(res <- read_workbook(path, sheet = "Clean"))
  expect_s3_class(res, "tbl_df")
  expect_s3_class(read_workbook(path, sheet = 2), "tbl_df")
})

test_that("read_workbook() keeps a list for a one-sheet workbook read whole", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx2::wb_workbook()$add_worksheet("Only")$add_data(x = data.frame(q = 1))$save(path)
  res <- read_workbook(path)
  expect_type(res, "list")
  expect_named(res, "Only")
})

test_that("read_workbook() reads a defined table and leaves its surroundings out", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  name <- inspect_excel(path, table = TRUE)$area[1] |> sub(pattern = " .*", replacement = "")
  expect_warning(res <- read_workbook(path, table = name), "were not read")
  expect_equal(names(res), c("a", "b"))
  expect_equal(nrow(res), 3)
})

test_that("read_workbook() reads all tables into a named list", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- suppressWarnings(read_workbook(path, table = TRUE))
  expect_type(res, "list")
  expect_length(res, 1)
})

test_that("read_workbook() leaves out a table's totals row", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx2::wb_workbook()$add_worksheet("S")$
    add_data_table(x = data.frame(n = 1:3), table_name = "Tot", total_row = TRUE)$
    save(path)
  res <- read_workbook(path, table = TRUE, check = FALSE)
  expect_equal(res[[1]]$n, c(1, 2, 3))
})

test_that("read_workbook() reads a range written with its sheet", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  res <- suppressWarnings(read_workbook(path, range = "Report!B3:C6"))
  expect_equal(res$b, c("x", "y", "z"))
})

test_that("read_workbook() warns once about the cells it left behind", {
  withr::local_dir(withr::local_tempdir())
  make_report_xlsx("report.xlsx")
  expect_snapshot(res <- read_workbook("report.xlsx"))
})

test_that("read_workbook() leaves a title above a range out of the warning", {
  withr::local_dir(withr::local_tempdir())
  make_report_xlsx("report.xlsx")
  expect_snapshot(res <- read_workbook("report.xlsx", range = "Report!B3:C6"))
})

test_that("read_workbook(check = FALSE) is silent", {
  path <- make_report_xlsx(withr::local_tempfile(fileext = ".xlsx"))
  expect_no_warning(suppressMessages(read_workbook(path, check = FALSE)))
})

test_that("read_workbook() explains bad sheet, range and table arguments", {
  withr::local_dir(withr::local_tempdir())
  make_report_xlsx("report.xlsx")
  expect_snapshot(read_workbook("report.xlsx", sheet = "Nope"), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", sheet = 5), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", range = "B3:C6"), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", range = c("B3:C6", "A1:A2")), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", range = c(Nope = "B3:C6")), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", sheet = "Clean", range = c(Report = "B3:C6")), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", range = c(Report = "B3-C6")), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", table = "Nope"), error = TRUE)
  expect_snapshot(read_workbook("report.xlsx", table = TRUE, sheet = 1), error = TRUE)
  expect_snapshot(read_workbook("missing.xlsx"), error = TRUE)
})

test_that("read_workbook() recognises a password-protected workbook", {
  withr::local_dir(withr::local_tempdir())
  # Encrypted .xlsx files are OLE containers; the signature is what matters
  writeBin(c(as.raw(c(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1)), raw(504)), "locked.xlsx")
  expect_snapshot(read_workbook("locked.xlsx"), error = TRUE)
})

test_that("read_workbook() reads detected ranges beyond row 99999", {
  skip_on_cran()
  path <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(x = seq_len(100001)), path)
  res <- read_workbook(path, sheet = 1)
  expect_equal(nrow(res), 100001)
})
