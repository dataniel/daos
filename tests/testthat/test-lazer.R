test_that("the forwarders say once per session that the function has moved", {
  rlang::reset_message_verbosity("daos_moved_to_lazer")
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines("x\n1", f)
  expect_message(read_files(f), class = "daos_moved_to_lazer")
  expect_no_message(read_files(f), class = "daos_moved_to_lazer")
})

test_that("read_files() still sees the caller's variables and unpacks there", {
  withr::local_dir(withr::local_tempdir())
  writeLines("x\n1", "dat1.csv")
  writeLines("x\n2", "dat2.csv")
  run <- function() {
    years <- 1:2
    suppressMessages(read_files("dat{years}.csv", names = paste0("d", years), out = "unpack"))
    c(exists("d1", inherits = FALSE), exists("d2", inherits = FALSE))
  }
  expect_equal(run(), c(TRUE, TRUE))
})

test_that("the TA forwarders keep their old signatures and layouts", {
  x <- data.frame(nrnr = "1", trans = "0100", brch = "A", bas = 1, eng = 2,
                  det = 3, afg = 4, moms = 5, kbx = 6)
  for (v in 1:2) {
    old <- withr::local_tempfile()
    new <- withr::local_tempfile()
    if (v == 1) suppressMessages(write_ta(x, old)) else suppressMessages(write_ta2(x, old))
    lazer::write_ta(x, new, version = v)
    expect_identical(readLines(old), readLines(new))
    back <- suppressMessages(if (v == 1) read_ta(old) else read_ta2(old))
    expect_equal(back, lazer::read_ta(new, version = v))
  }
})

test_that("the other forwarders call lazer", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  suppressMessages(write_excel(data.frame(q = 1:2), path))
  expect_equal(suppressMessages(read_workbook(path, sheet = 1))$q, 1:2)
  expect_equal(nrow(suppressMessages(inspect_excel(path))), 0)
})
