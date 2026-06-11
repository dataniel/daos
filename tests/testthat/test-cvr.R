# These tests are strictly offline: cvr_query() is a pure list builder,
# cvr_hits() is fed a synthetic response fixture, and the cvr_download()
# tests only exercise validation that aborts before any download is
# attempted. cvr_search() is deliberately untested -- it must never be
# called against the live CVR API from tests.

test_that("cvr_query() builds the expected query structure", {
  q <- cvr_query(c("12345678", "87654321"), "2024-01-01", "2024-12-31")

  must <- q$query$bool$must
  expect_equal(must[[1]]$terms$cvrNummer, I(c("12345678", "87654321")))
  expect_equal(must[[2]]$term[["dokumenter.dokumentType"]], "aarsrapport")
  expect_equal(
    must[[3]]$range[["regnskab.regnskabsperiode.slutDato"]],
    list(gte = "2024-01-01T00:00:00.000Z", lte = "2024-12-31T23:59:59.999Z")
  )
  expect_equal(q$size, 2999)
})

test_that("cvr_query() accepts numeric cvr and Date dates", {
  q <- cvr_query(12345678, as.Date("2024-01-01"), as.Date("2024-12-31"))
  expect_equal(q$query$bool$must[[1]]$terms$cvrNummer, I("12345678"))
})

test_that("cvr_query() keeps a single cvr as a JSON array", {
  skip_if_not_installed("jsonlite")
  q <- cvr_query("12345678", "2024-01-01", "2024-12-31")
  json <- as.character(jsonlite::toJSON(q, auto_unbox = TRUE))
  expect_match(json, '"cvrNummer":["12345678"]', fixed = TRUE)
})

test_that("cvr_query() validates cvr numbers", {
  expect_error(cvr_query("1234567", "2024-01-01", "2024-12-31"), "8 digits")
  expect_error(cvr_query("1234567a", "2024-01-01", "2024-12-31"), "8 digits")
  expect_error(
    cvr_query(sprintf("%08d", 1:1001), "2024-01-01", "2024-12-31"),
    "at most 1000"
  )
})

test_that(".scroll_url() targets /_search/scroll at the host root", {
  expect_equal(
    .scroll_url("http://distribution.virk.dk/offentliggoerelser/_search"),
    "http://distribution.virk.dk/_search/scroll"
  )
  expect_equal(
    .scroll_url("https://example.com:9200/index/_search"),
    "https://example.com:9200/_search/scroll"
  )
})

test_that("cvr_search() validates the scroll argument", {
  skip_if_not_installed("curl")
  skip_if_not_installed("jsonlite")
  q <- cvr_query("12345678", "2024-01-01", "2024-12-31")
  expect_error(cvr_search(q, contact = "x@y.dk", scroll = "ja"), "scroll")
  expect_error(cvr_search(q, contact = "x@y.dk", scroll = 0), "scroll")
})

test_that("cvr_query() validates dates", {
  expect_error(cvr_query("12345678", NULL, "2024-12-31"), "valid date")
  expect_error(cvr_query("12345678", "2024-01-01", "ikke en dato"), "valid date")
  expect_error(
    cvr_query("12345678", "2024-12-31", "2024-01-01"),
    "must not be later"
  )
})

# Synthetic response shaped like a parsed Elasticsearch reply; never the
# result of a real API call
fake_response <- list(hits = list(hits = list(
  list(`_source` = list(
    cvrNummer = "12345678",
    regnskab = list(regnskabsperiode = list(slutDato = "2024-12-31")),
    dokumenter = list(
      list(dokumentUrl = "http://example.invalid/a.pdf", dokumentType = "aarsrapport"),
      list(dokumentUrl = "http://example.invalid/b.xml", dokumentType = "andet")
    )
  )),
  list(`_source` = list(
    cvrNummer = "87654321",
    dokumenter = list(
      list(dokumentUrl = "http://example.invalid/c.pdf", dokumentType = "aarsrapport")
    )
  ))
)))

test_that("cvr_hits() flattens hits to one row per document", {
  res <- suppressMessages(cvr_hits(fake_response))

  expect_equal(nrow(res), 3)
  expect_true(all(c("cvrnummer", "dokumenturl", "dokumenttype") %in% names(res)))
  expect_equal(res$cvrnummer, c("12345678", "12345678", "87654321"))
  expect_equal(
    res$dokumenturl,
    paste0("http://example.invalid/", c("a.pdf", "b.xml", "c.pdf"))
  )
})

test_that("cvr_hits() recycles single-valued fields across documents", {
  res <- suppressMessages(cvr_hits(fake_response))
  expect_equal(res$slutdato[1:2], c("2024-12-31", "2024-12-31"))
})

test_that("cvr_hits() warns on empty responses and missing columns", {
  expect_warning(empty <- cvr_hits(list(hits = list(hits = list()))), "no hits")
  expect_equal(nrow(empty), 0)

  no_url <- list(hits = list(hits = list(
    list(`_source` = list(cvrNummer = "12345678"))
  )))
  expect_warning(suppressMessages(cvr_hits(no_url)), "dokumenturl")
})

test_that("cvr_download() validates input before downloading anything", {
  skip_if_not_installed("curl")
  dir <- withr::local_tempdir()

  expect_error(
    cvr_download(tibble::tibble(cvrnummer = "12345678"), dir),
    "dokumenturl"
  )
  expect_error(
    cvr_download(tibble::tibble(cvrnummer = character(), dokumenturl = character()), dir),
    "empty"
  )
  expect_error(
    cvr_download(
      tibble::tibble(cvrnummer = "12345678", dokumenturl = "http://example.invalid/a.pdf"),
      dir,
      sleep = 0
    ),
    "at least 1 second"
  )
})

test_that("cvr_download() aborts on existing files before downloading anything", {
  skip_if_not_installed("curl")
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "12345678.pdf"))

  expect_error(
    cvr_download(
      tibble::tibble(cvrnummer = "12345678", dokumenturl = "http://example.invalid/a.pdf"),
      dir
    ),
    "Would overwrite"
  )
})
