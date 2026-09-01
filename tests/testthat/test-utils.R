test_that("format_elapsed() formats milliseconds", {
  expect_equal(format_elapsed(as.difftime(0.1, units = "secs")), "100ms")
  expect_equal(format_elapsed(as.difftime(0,   units = "secs")), "0ms")
})

test_that("format_elapsed() formats seconds", {
  expect_equal(format_elapsed(as.difftime(2.3, units = "secs")), "2.3s")
  expect_equal(format_elapsed(as.difftime(59,  units = "secs")), "59s")
})

test_that("format_elapsed() formats minutes", {
  expect_equal(format_elapsed(as.difftime(90, units = "secs")), "1.5m")
  expect_equal(format_elapsed(as.difftime(60, units = "secs")), "1m")
})

test_that(".path_link() falls back to plain text without hyperlink support", {
  withr::local_options(cli.hyperlink = FALSE, cli.hyperlink_run = FALSE)
  path <- withr::local_tempfile()
  expect_equal(as.character(.path_link(path, "label")), "label")
})

test_that(".path_link() links files to their absolute file:// path", {
  withr::local_options(cli.hyperlink = TRUE)
  path <- withr::local_tempfile()
  writeLines("x", path)

  link <- .path_link(path, basename(path))
  expect_match(link, "file://", fixed = TRUE)
  expect_match(link, normalizePath(path, winslash = "/"), fixed = TRUE)
})

test_that(".path_link() uses an Explorer run-link for directories in RStudio", {
  withr::local_envvar(RSTUDIO = "1")
  withr::local_options(cli.hyperlink = TRUE, cli.hyperlink_run = TRUE)
  dir <- withr::local_tempdir()

  link <- .path_link(dir)
  expect_match(link, "x-r-run", fixed = TRUE)
  expect_match(link, "daos::open_in_explorer", fixed = TRUE)
})
