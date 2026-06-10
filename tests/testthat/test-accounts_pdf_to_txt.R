skip_if_not_installed("pdftools")

# A pdf() device with a plot produces extractable text (axis labels etc.);
# plot.new() alone produces none, mimicking a scanned PDF.
make_pdf <- function(dir, name, blank = FALSE) {
  grDevices::pdf(file.path(dir, paste0(name, ".pdf")))
  if (blank) plot.new() else plot(1:10, main = name)
  grDevices::dev.off()
}

make_dirs <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  pdf_dir <- file.path(root, "pdf")
  dir.create(pdf_dir)
  list(pdf = pdf_dir, txt = file.path(root, "txt"))
}

test_that("writes one txt file per pdf and returns the paths", {
  d <- make_dirs()
  make_pdf(d$pdf, "11111111")
  make_pdf(d$pdf, "22222222")

  res <- suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt))

  expect_setequal(basename(res), c("11111111.txt", "22222222.txt"))
  expect_true(all(file.exists(res)))
  expect_true(all(nzchar(trimws(sapply(res, \(f) paste(readLines(f), collapse = ""))))))
})

test_that("creates txt_dir automatically", {
  d <- make_dirs()
  make_pdf(d$pdf, "11111111")

  expect_false(dir.exists(d$txt))
  suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt))
  expect_true(dir.exists(d$txt))
})

test_that("skips pdfs with no extractable text", {
  d <- make_dirs()
  make_pdf(d$pdf, "11111111")
  make_pdf(d$pdf, "99999999", blank = TRUE)

  msgs <- capture_messages(res <- accounts_pdf_to_txt(d$pdf, d$txt))

  expect_true(any(grepl("99999999.*skipped", msgs)))
  expect_equal(basename(res), "11111111.txt")
  expect_false(file.exists(file.path(d$txt, "99999999.txt")))
})

test_that("errors when pdf_dir contains no pdfs", {
  d <- make_dirs()
  expect_error(accounts_pdf_to_txt(d$pdf, d$txt), "No PDF files found")
})

test_that("errors if txt files exist and overwrite = FALSE", {
  d <- make_dirs()
  make_pdf(d$pdf, "11111111")
  suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt))

  expect_error(
    suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt)),
    "Would overwrite"
  )
})

test_that("overwrites existing txt files when overwrite = TRUE", {
  d <- make_dirs()
  make_pdf(d$pdf, "11111111")
  suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt))

  expect_no_error(
    suppressMessages(accounts_pdf_to_txt(d$pdf, d$txt, overwrite = TRUE))
  )
})
