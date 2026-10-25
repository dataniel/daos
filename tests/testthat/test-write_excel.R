skip_if_not_installed("openxlsx2")

tmp <- function() tempfile(fileext = ".xlsx")

test_that("digits controls display without rounding stored values", {
  df <- data.frame(amount = c(1234.567, -2345.678), year = c(2020, 2021),
                   period = c(202001, 202002), small = c(1.234, 2.345))
  for (digits in list(0, 2, NULL)) {
    path <- tmp()
    write_excel(df, path, digits = digits, skip_fmt = "period")
    wb <- openxlsx2::wb_load(path)
    expect_equal(openxlsx2::wb_to_df(wb)$amount, df$amount)
    cells <- wb$worksheets[[1]]$sheet_data$cc
    styles <- cells$c_s[cells$c_r == "A" & cells$row_r != "1"]
    if (is.null(digits)) {
      expect_true(all(styles == "" | is.na(styles)))
    } else {
      folder <- tempfile()
      dir.create(folder)
      unzip(path, files = "xl/styles.xml", exdir = folder)
      xml <- paste(readLines(file.path(folder, "xl/styles.xml"), warn = FALSE), collapse = "")
      expected <- if (digits == 2) '#,##0.00' else '#,##0'
      expect_true(grepl(paste0('formatCode="', expected, '"'), xml, fixed = TRUE))
      expect_true(all(styles != "" & !is.na(styles)))
    }
    untouched <- cells$c_s[cells$c_r %in% c("B", "C", "D") & cells$row_r != "1"]
    expect_true(all(untouched == "" | is.na(untouched)))
  }
  for (digits in list(-1, 1.5, NA_real_, Inf, 16, "2", c(1, 2)))
    expect_error(write_excel(df, tmp(), digits = digits), "digits")
})

test_that("missing numeric values produce blank cells without warnings", {
  for (as_table in c(FALSE, TRUE)) {
    path <- tmp()
    expect_no_warning(write_excel(data.frame(x = c(1, NA_real_), empty = c(NA_real_, NA_real_)),
                                  path, as_table = as_table))
    cells <- openxlsx2::wb_load(path)$worksheets[[1]]$sheet_data$cc
    expect_false(any(cells$c_t == "e", na.rm = TRUE))
    expect_false(any(cells$v == "#N/A", na.rm = TRUE))
    expect_true(any(cells$r == "A2" & cells$v == "1"))
  }
})

test_that("invalid sheet inputs fail before writing a workbook", {
  path <- tmp()
  for (nms in list(c("A", "A"), c("A", "a"), c("Sheet2", ""))) {
    expect_error(write_excel(setNames(list(mtcars, iris), nms), path), "unique")
    expect_false(file.exists(path))
  }
  for (nm in c("a/b", "a\\b", "a?b", "a*b", "a[b", "a]b", "a:b", "'a", "a'", strrep("a", 32))) {
    expect_error(write_excel(setNames(list(mtcars), nm), path), "Invalid Excel")
  }
  expect_error(write_excel(list(), path), "non-empty")
  expect_error(write_excel(list(A = 1:3), path), "data frames")
  expect_error(write_excel(setNames(list(mtcars), NA_character_), path), "must not be NA")
})

test_that("creates a new file from a single data frame", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_true(file.exists(path))
})

test_that("single df defaults to sheet named Sheet1", {
  path <- tmp()
  write_excel(mtcars, path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, "Sheet1")
})

test_that("named list produces correct sheet names", {
  path <- tmp()
  write_excel(list(Cars = mtcars, Iris = iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Cars", "Iris"))
})

test_that("unnamed list gets default sheet names", {
  path <- tmp()
  write_excel(list(mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Sheet1", "Sheet2"))
})

test_that("mixed named/unnamed list uses name where given", {
  path <- tmp()
  write_excel(list(Hoved = mtcars, iris), path)
  wb <- openxlsx2::wb_load(path)
  expect_equal(wb$sheet_names, c("Hoved", "Sheet2"))
})

test_that("errors if file exists and mode is new", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_error(write_excel(mtcars, path), "already exists")
})

test_that("overwrites file in overwrite mode", {
  path <- tmp()
  write_excel(mtcars, path)
  expect_no_error(write_excel(mtcars, path, mode = "overwrite"))
})

test_that("errors on a non-xlsx path", {
  expect_error(write_excel(mtcars, tempfile(fileext = ".xls")), "xlsx")
  expect_error(write_excel(mtcars, tempfile(fileext = ".csv")), "xlsx")
})

test_that("returns path invisibly", {
  path <- tmp()
  result <- write_excel(mtcars, path)
  expect_equal(result, path)
})

test_that(".xl_is_yearlike() detects year columns", {
  expect_true(daos:::.xl_is_yearlike(c(2019, 2020, 2021)))
  expect_true(daos:::.xl_is_yearlike(c(1995L, NA, 2024L)))
  expect_false(daos:::.xl_is_yearlike(c(2020, 12345)))     # outside range
  expect_false(daos:::.xl_is_yearlike(c(2020.5, 2021)))    # not whole numbers
  expect_false(daos:::.xl_is_yearlike(c(NA_real_, NA_real_)))
})

test_that("year-like columns are excluded from the number format", {
  df <- data.frame(year = c(2019, 2020), amount = c(1234567, 2345678))
  path <- tmp()
  write_excel(df, path)
  wb <- openxlsx2::wb_load(path)
  styled_dims <- wb$worksheets[[1]]$sheet_data$cc
  # amount cells carry a style, year cells do not
  amount_styles <- styled_dims$c_s[styled_dims$c_r == "B" & styled_dims$row_r != "1"]
  year_styles   <- styled_dims$c_s[styled_dims$c_r == "A" & styled_dims$row_r != "1"]
  expect_true(all(amount_styles != ""))
  expect_true(all(year_styles == "" | is.na(year_styles)))
})

test_that("detect_years = FALSE formats year columns again", {
  df <- data.frame(year = c(2019, 2020), amount = c(1234567, 2345678))
  path <- tmp()
  write_excel(df, path, detect_years = FALSE)
  wb <- openxlsx2::wb_load(path)
  styled_dims <- wb$worksheets[[1]]$sheet_data$cc
  year_styles <- styled_dims$c_s[styled_dims$c_r == "A" & styled_dims$row_r != "1"]
  expect_true(all(year_styles != ""))
})
