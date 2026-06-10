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

test_that(".fill_down() carries the last non-NA value forward", {
  expect_equal(.fill_down(c("a", NA, NA, "b", NA)), c("a", "a", "a", "b", "b"))
  expect_equal(.fill_down(c(1, NA, 3)), c(1, 1, 3))
})

test_that(".fill_down() keeps leading NAs and handles edge cases", {
  expect_equal(.fill_down(c(NA, NA, "x", NA)), c(NA, NA, "x", "x"))
  expect_equal(.fill_down(character(0)), character(0))
  expect_equal(.fill_down(c(NA_character_, NA_character_)),
               c(NA_character_, NA_character_))
})

test_that(".split3() splits into exactly three fields", {
  out <- .split3(c("a   b   c", "category line", "x   1.000   "), " {3,}")
  expect_equal(out[1, ], c(V1 = "a", V2 = "b", V3 = "c"))
  expect_equal(out[2, ], c(V1 = "category line", V2 = "", V3 = ""))
  expect_equal(out[3, ], c(V1 = "x", V2 = "1.000", V3 = ""))
})

test_that(".split3() keeps extra delimiters in the third field", {
  out <- .split3("a   b   c   d", " {3,}")
  expect_equal(out[1, ], c(V1 = "a", V2 = "b", V3 = "c   d"))
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
  expect_match(link, ".open_in_explorer", fixed = TRUE)
})
