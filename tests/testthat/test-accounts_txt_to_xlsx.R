skip_if_not_installed("writexl")

# Standard well-formed company file: two categories, one statnatio-negated,
# one element without a previous-year value.
ok_lines <- c(
  "Resultatopgoerelse",
  "Nettoomsaetning   1.234.000   1.100.000",
  "Andre indtaegter   200.000",
  "Omkostninger statnatio",
  "Loen   500.000   400.000"
)

make_dirs <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  txt_dir <- file.path(root, "txt")
  dir.create(txt_dir)
  list(txt = txt_dir, out = file.path(root, "out.xlsx"))
}

write_txt <- function(dir, name, lines) {
  writeLines(lines, file.path(dir, paste0(name, ".txt")))
}

run <- function(d, ...) {
  suppressMessages(accounts_txt_to_xlsx(d$txt, d$out, year = 2025, ...))
}

test_that("parses categories, elements, years and values correctly", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)

  res <- run(d)

  expect_equal(
    as.data.frame(res),
    data.frame(
      cvr       = "11111111",
      note      = rep(c("resultatopgoerelse", "resultatopgoerelse", "omkostninger"), each = 2),
      elementid = rep(c("nettoomsaetning", "andre indtaegter", "loen"), each = 2),
      year      = rep(c(2025, 2024), times = 3),
      val       = c(1234, 1100, 200, NA, -500, -400)
    )
  )
})

test_that("statnatio negates values and is stripped from the note", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)

  res <- run(d)
  loen <- res[res$elementid == "loen", ]

  expect_equal(loen$note, c("omkostninger", "omkostninger"))
  expect_true(all(loen$val < 0))
})

test_that("a _spec suffix is stripped from the cvr", {
  d <- make_dirs()
  write_txt(d$txt, "11111111_spec", ok_lines)

  res <- run(d)
  expect_equal(unique(res$cvr), "11111111")
})

test_that("multiple files are combined with one cvr per file", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)
  write_txt(d$txt, "22222222", ok_lines)

  res <- run(d)
  expect_setequal(unique(res$cvr), c("11111111", "22222222"))
  expect_equal(nrow(res), 12)
})

test_that("writes the xlsx file and returns the data invisibly", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)

  res <- run(d)
  expect_true(file.exists(d$out))
  expect_s3_class(res, "tbl_df")
})

test_that("min_spaces controls the field delimiter", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Balance", "Aktiver i alt  9.000.000  8.500.000"))

  res <- run(d, min_spaces = 2)
  expect_equal(res$val, c(9000, 8500))
})

test_that("files with no data lines are skipped with a warning", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)
  # Two spaces only: not a delimiter by default, so every line is a category
  # line and the file contributes no data rows
  write_txt(d$txt, "22222222", c("Balance", "Aktiver i alt  9.000.000  8.500.000"))

  msgs <- capture_messages(res <- accounts_txt_to_xlsx(d$txt, d$out, year = 2025))

  expect_true(any(grepl("22222222.*skipped", msgs)))
  expect_equal(unique(res$cvr), "11111111")
})

test_that("aborts when no file yields any data lines", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Balance", "Aktiver i alt  9.000.000  8.500.000"))

  expect_error(run(d), "No data lines")
  expect_false(file.exists(d$out))
})

test_that("commas in value columns abort with file and line numbers", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Balance", "Aktiver   9.000,50   8.500.000"))

  err <- expect_error(run(d), "comma in value columns")
  expect_match(conditionMessage(err), "line 2")
})

test_that("data lines before the first category line abort", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Orphan   100.000   90.000", "Balance", "Aktiver   1.000   2.000"))

  expect_error(run(d), "NA in note or elementid")
})

test_that("non-numeric current-year values abort", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Balance", "Aktiver   unknown   8.500.000"))

  err <- expect_error(run(d), "non-numeric value in current year")
  expect_match(conditionMessage(err), "aktiver")
})

test_that("validation errors are collected across all companies", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)
  write_txt(d$txt, "22222222", c("Balance", "Aktiver   9.000,50   8.500.000"))
  write_txt(d$txt, "33333333", c("Balance", "Aktiver   unknown   8.500.000"))

  err <- expect_error(run(d), "Validation failed for 2 of 3 companies")
  expect_match(conditionMessage(err), "22222222")
  expect_match(conditionMessage(err), "33333333")
})

test_that("nothing is written when validation fails", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", c("Balance", "Aktiver   9.000,50   8.500.000"))

  expect_error(run(d))
  expect_false(file.exists(d$out))
})

test_that("long issue lists are truncated", {
  d <- make_dirs()
  for (i in 1:11)
    write_txt(d$txt, sprintf("%08d", i), c("Balance", "Aktiver   9.000,50   8.500.000"))

  err <- expect_error(run(d), "Validation failed for 11 of 11 companies")
  expect_match(conditionMessage(err), "1 more issue")
})

test_that("errors when txt_dir contains no txt files", {
  d <- make_dirs()
  expect_error(run(d), "No txt files found")
})

test_that("errors if out_file exists and overwrite = FALSE", {
  d <- make_dirs()
  write_txt(d$txt, "11111111", ok_lines)
  run(d)

  expect_error(run(d), "Would overwrite")
  expect_no_error(run(d, overwrite = TRUE))
})
