make_ta_df <- function() {
  tibble::tibble(
    nrnr  = "12345",
    trans = "123456",
    brch  = "1234",
    bas   = 100.00,
    eng   =  50.00,
    det   =  30.00,
    afg   =  10.00,
    moms  =   5.00,
    kbx   =   2.00
  )
}

test_that("write_ta() round-trips through read_ta() for the nine columns", {
  df <- make_ta_df()
  path <- withr::local_tempfile()
  write_ta(df, path)

  result <- read_ta(path)
  expect_equal(result$nrnr,  df$nrnr)
  expect_equal(result$trans, df$trans)
  expect_equal(result$brch,  df$brch)
  expect_equal(result$bas,   df$bas)
  expect_equal(result$eng,   df$eng)
  expect_equal(result$moms,  df$moms)
  expect_equal(result$kbx,   df$kbx)
})

test_that("write_ta() returns path invisibly", {
  path <- withr::local_tempfile()
  result <- write_ta(make_ta_df(), path)
  expect_equal(result, path)
})

test_that("write_ta() handles NA as blank fields", {
  df <- make_ta_df()
  df$eng <- NA_real_
  path <- withr::local_tempfile()
  write_ta(df, path)

  result <- read_ta(path)
  expect_true(is.na(result$eng))
})

test_that("write_ta() derives moms when column is absent", {
  df <- tibble::tibble(
    nrnr  = c("12345", "12345", "12345"),
    trans = c("0100",  "0700",  "0200"),
    brch  = "1234",
    bas   = 100.00,
    eng   =  50.00,
    det   =  30.00,
    afg   =  10.00,
    kbx   =   2.00
  )
  path <- withr::local_tempfile()
  expect_message(write_ta(df, path), "`moms` not found")

  result <- read_ta(path)
  expect_true(is.na(result$moms[1]))   # trans 0100 -> NA
  expect_true(is.na(result$moms[2]))   # trans 0700 -> NA
  expect_equal(result$moms[3], 0)      # other trans -> 0
})

test_that("write_ta() errors on unknown columns", {
  df <- make_ta_df()
  df$prim <- 99
  expect_error(write_ta(df, tempfile()), "Remove: prim")
})
