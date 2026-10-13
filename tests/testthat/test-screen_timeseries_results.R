test_that("insights distinguish unavailable diagnostics from no detected candidates", {
  r <- screen_ts_diagnose(1:40, rep(7, 40), features = "outliers")
  f <- screen_ts_findings(r, c("outliers", "breaks"))
  expect_match(f[[1]]$title, "No outlier candidates")
  expect_match(f[[2]]$title, "unavailable")
  r$n_breaks <- 0L
  expect_match(screen_ts_findings(r, "breaks")[[1]]$title, "No break selected")
  r$n_outliers <- NA_integer_
  expect_match(screen_ts_findings(r, "outliers")[[1]]$title, "unavailable")
  missing <- screen_ts_diagnose(1:4, rep(NA_real_, 4), features = "summary")
  expect_match(screen_ts_findings(missing, "summary")[[1]]$title, "No finite")
})

test_that("stationarity conclusions respect opposing null hypotheses", {
  r <- screen_ts_diagnose(1:40, sin(1:40), features = "summary")
  r$tests[[1]] <- data.frame(test = c("KPSS", "PP"), statistic = c(1, 2),
    p_value = c(.01, .5), null_hypothesis = c("Level stationarity", "Unit root"),
    interpretation = c("Evidence against level stationarity", "Unit root not rejected"))
  expect_match(screen_ts_findings(r, "stationarity")[[1]]$title, "against level stationarity")
  r$tests[[1]]$p_value <- c(.5, .01)
  expect_match(screen_ts_findings(r, "stationarity")[[1]]$title, "consistent with level stationarity")
  r$tests[[1]]$p_value <- c(.01, .01)
  expect_match(screen_ts_findings(r, "stationarity")[[1]]$title, "mixed")
  r$tests[[1]]$p_value <- c(.5, .5)
  expect_match(screen_ts_findings(r, "stationarity")[[1]]$title, "mixed")
})

test_that("result presentation handles missing values and escapes group content", {
  skip_if_not_installed("shiny")
  r <- screen_ts_diagnose(1:5, rep(NA_real_, 5), features = "summary")
  expect_equal(screen_ts_format(NA_real_), "\u2014")
  expect_equal(screen_ts_format(Inf), "\u2014")
  expect_equal(screen_ts_format(0), "0")
  overview <- as.character(screen_ts_overview(r))
  expect_match(overview, "Data quality")
  expect_false(grepl(">NaN<|>Inf<|>NA<", overview))
  html <- as.character(screen_ts_insights(r, "summary", "<script>alert(1)</script>"))
  expect_match(html, "&lt;script&gt;", fixed = TRUE)
  expect_false(grepl("<script>", html, fixed = TRUE))
})

test_that("compact findings link to their own analysis regardless of selection order", {
  skip_if_not_installed("shiny")
  r <- screen_ts_diagnose(1:40, rep(7, 40), features = c("summary", "outliers"))
  html <- as.character(screen_ts_insights(r, c("outliers", "summary"), "<series>", compact = TRUE))
  expect_match(html, "data-diagnostic-tab=\"summary\">[[:space:]]*<span class=\"insight-tool\">Statistics")
  expect_match(html, "data-diagnostic-tab=\"outliers\">[[:space:]]*<span class=\"insight-tool\">Outliers")
  expect_match(html, "&lt;series&gt;", fixed = TRUE)
})

test_that("compact outlier results retain access to every candidate", {
  skip_if_not_installed("shiny")
  r <- screen_ts_diagnose(1:40, rep(7, 40), features = "summary")
  r$n_outliers <- 8L
  r$outliers[[1]] <- data.frame(time = paste0("observation-", 1:8), value = 1:8, score = rep(5, 8))
  compact <- as.character(screen_ts_outlier_results(r, compact = TRUE))
  full <- as.character(screen_ts_outlier_results(r))
  expect_match(compact, "All 8 candidates")
  expect_match(compact, "observation-4")
  expect_false(grepl("observation-5", compact, fixed = TRUE))
  expect_match(full, "observation-8")
  expect_match(full, "absolute score &gt; 4.5", fixed = TRUE)
})
