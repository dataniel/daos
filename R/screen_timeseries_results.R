# Presentation helpers keep interpretation testable without a browser.
screen_ts_format <- function(value, digits = 4) {
  if (!length(value) || is.na(value) || !is.finite(value)) return("\u2014")
  format(signif(value, digits), trim = TRUE, big.mark = ",",
    scientific = abs(value) >= 1e7 || (value != 0 && abs(value) < 0.001))
}

screen_ts_findings <- function(r, features) {
  findings <- list()
  add <- function(tool, title, detail, tone = "neutral") {
    findings[[length(findings) + 1L]] <<- list(tool = tool, title = title, detail = detail, tone = tone)
  }
  unavailable <- function(tool, detail = "See the method notes for the data or package requirements.") {
    add(tool, paste(tool, "unavailable"), detail, "unavailable")
  }
  fmt <- screen_ts_format
  if ("summary" %in% features) {
    issues <- c("missing values" = r$missing, "infinite values" = r$non_finite,
      "missing times" = r$missing_time, "duplicate times" = r$duplicate_times,
      "missing periods" = r$missing_periods)
    issues <- issues[!is.na(issues) & issues > 0]
    if (!r$n_finite) {
      add("Statistics", "No finite measurements", "Descriptive values cannot be calculated for this view.", "unavailable")
    } else if (length(issues)) {
      add("Statistics", "Data quality needs attention",
        paste(paste(unname(issues), names(issues)), collapse = " \u00b7 "), "attention")
    } else {
      add("Statistics", paste(fmt(r$n), "observations in this view"),
        paste0("Latest value ", fmt(r$last),
          if (is.finite(r$change_pct)) paste0("; ", if (r$change_pct > 0) "+" else "",
            fmt(r$change_pct, 3), "% versus the previous observation.") else ".",
          if (!isTRUE(r$regular)) " Regular time spacing could not be established." else ""))
    }
  }
  if ("seasonality" %in% features) {
    if (r$period <= 1) {
      add("Seasonality", "Choose a seasonal period",
        "Set the period above 1; for example, 12 for annual seasonality in monthly data.", "unavailable")
    } else if (!is.finite(r$seasonal_strength)) {
      unavailable("Seasonality")
    } else {
      add("Seasonality", "Seasonal component estimated",
        paste0("Strength ", fmt(r$seasonal_strength, 3), " on a 0\u20131 scale, with a period of ",
          fmt(r$period), " observations."), "pattern")
    }
  }
  if ("outliers" %in% features) {
    if (is.na(r$n_outliers)) {
      unavailable("Outlier screening")
    } else if (r$n_outliers > 0) {
      add("Outliers", paste(r$n_outliers, if (r$n_outliers == 1) "observation to review" else "observations to review"),
        "Highlighted points are residual-screening candidates. Review them in the context of the series.", "attention")
    } else {
      add("Outliers", "No outlier candidates detected",
        "The selected screening method did not identify unusual observations.")
    }
  }
  if ("stationarity" %in% features) {
    tests <- r$tests[[1]]
    if (!nrow(tests)) {
      unavailable("Stationarity tests")
    } else {
      kpss <- tests$p_value[tests$null_hypothesis == "Level stationarity"]
      pp <- tests$p_value[tests$null_hypothesis == "Unit root"]
      if (length(kpss) == 1 && length(pp) == 1 && all(is.finite(c(kpss, pp)))) {
        if (kpss < .05 && pp >= .05) {
          add("Stationarity", "Evidence against level stationarity",
            "KPSS rejects level stationarity; Phillips\u2013Perron does not reject a unit root (5% threshold).", "attention")
        } else if (kpss >= .05 && pp < .05) {
          add("Stationarity", "Tests consistent with level stationarity",
            "KPSS does not reject level stationarity; Phillips\u2013Perron rejects a unit root. This is not proof of stability.", "pattern")
        } else {
          add("Stationarity", "Tests give a mixed signal",
            "The two tests do not point to the same conclusion. Inspect their assumptions and the observed pattern.", "attention")
        }
      } else add("Stationarity", "Partial test results", paste(tests$interpretation, collapse = ". "))
    }
  }
  if ("autocorrelation" %in% features) {
    d <- r$correlation[[1]]
    d <- d[d$lag > 0 & is.finite(d$acf), , drop = FALSE]
    if (!nrow(d)) {
      unavailable("Autocorrelation")
    } else {
      limit <- 1.96 / sqrt(r$n)
      beyond <- abs(d$acf) > limit
      add("Autocorrelation",
        if (any(beyond)) "Dependence across observations" else "No scanned lags exceed the reference limits",
        paste0(sum(beyond), " of ", nrow(d), " ACF lags exceed approximate white-noise limits. ",
          "Trend and seasonality can contribute."),
        if (any(beyond)) "pattern" else "neutral")
    }
  }
  if ("breaks" %in% features) {
    if (is.na(r$n_breaks)) {
      unavailable("Break detection")
    } else if (r$n_breaks) {
      add("Structural breaks", paste(r$n_breaks, if (r$n_breaks == 1) "candidate change point" else "candidate change points"),
        "Dates are conditional on the selected model. Inspect the shifts and their confidence intervals.", "attention")
    } else {
      add("Structural breaks", "No break selected by this model",
        "BIC selected no change points under the chosen model; this does not rule out all structural changes.")
    }
  }
  findings
}

screen_ts_insights <- function(r, features, series_label, compact = FALSE) {
  findings <- screen_ts_findings(r, features)
  feature_order <- c("summary", "seasonality", "outliers", "stationarity", "autocorrelation", "breaks")
  selected <- feature_order[feature_order %in% features]
  shiny::tagList(
    shiny::div(class = "insights-heading", shiny::h3("Screening insights"),
      shiny::span(class = "series-badge", series_label)),
    shiny::div(class = "insights-grid", lapply(seq_along(findings), function(i) {
      f <- findings[[i]]
      if (compact) return(shiny::tags$button(type = "button",
        class = paste("insight insight-link", paste0("insight-", f$tone)),
        "data-diagnostic-tab" = selected[i],
        shiny::span(class = "insight-tool", f$tool), shiny::strong(f$title),
        shiny::span(class = "insight-arrow", "aria-hidden" = "true", "\u2197")))
      shiny::div(class = paste("insight", paste0("insight-", f$tone)),
        shiny::span(class = "insight-tool", f$tool),
        shiny::h4(f$title), shiny::p(f$detail))
    }))
  )
}

screen_ts_finding <- function(r, feature, series_label) {
  f <- screen_ts_findings(r, feature)[[1]]
  shiny::div(class = paste("insight", paste0("insight-", f$tone)),
    shiny::span(class = "insight-tool", paste(f$tool, "\u00b7", series_label)),
    shiny::h4(f$title), shiny::p(f$detail))
}

screen_ts_metric <- function(label, value, detail = NULL) {
  shiny::div(class = "metric",
    shiny::span(class = "metric-label", label),
    shiny::strong(class = "metric-value", value),
    if (!is.null(detail)) shiny::span(class = "metric-detail", detail))
}

screen_ts_overview <- function(r, compact = FALSE) {
  fmt <- screen_ts_format
  distribution <- c("Minimum" = r$min, "25%" = r$q25, "Median" = r$median,
    "75%" = r$q75, "Maximum" = r$max)
  shiny::tagList(
    shiny::div(class = "sample-period",
      paste(if (is.na(r$start)) "\u2014" else r$start, "\u2013",
        if (is.na(r$end)) "\u2014" else r$end),
      shiny::span(paste(fmt(r$n), "observations"))),
    shiny::div(class = "metric-grid",
      screen_ts_metric("Latest value", fmt(r$last)),
      screen_ts_metric("Last change",
        if (is.finite(r$change_pct)) paste0(if (r$change_pct > 0) "+" else "", fmt(r$change_pct, 3), "%") else "\u2014",
        paste(fmt(r$change), "in original units")),
      screen_ts_metric("Mean", fmt(r$mean)),
      screen_ts_metric("Standard deviation", fmt(r$sd))),
    shiny::h4(class = "detail-label", "Distribution",
      if (compact) shiny::actionButton("show_quality", "Data quality \u2197", class = "link-btn")),
    shiny::div(class = "distribution-strip", lapply(seq_along(distribution), function(i)
      shiny::div(shiny::span(names(distribution)[i]), shiny::strong(fmt(distribution[i]))))),
    if (!compact) shiny::tags$details(class = "result-disclosure",
      shiny::tags$summary("Data quality", shiny::span(class = "disclosure-hint", "6 checks")),
      screen_ts_quality(r))
  )
}

screen_ts_quality <- function(r) {
  quality <- c("Finite values" = r$n_finite, "Missing values" = r$missing,
    "Infinite values" = r$non_finite, "Missing times" = r$missing_time,
    "Duplicate times" = r$duplicate_times, "Missing periods" = r$missing_periods)
  shiny::tagList(
    shiny::div(class = "quality-grid", lapply(seq_along(quality), function(i)
      shiny::div(class = paste("quality-item", if (!is.na(quality[i]) && i > 1 && quality[i] > 0) "has-issue"),
        shiny::span(names(quality)[i]), shiny::strong(screen_ts_format(quality[i]))))),
    shiny::p(class = "result-footnote", "Missing periods are counted on the inferred time grid."))
}

screen_ts_strengths <- function(r) {
  meter <- function(label, value) shiny::div(class = "strength",
    shiny::div(shiny::span(label), shiny::strong(screen_ts_format(value, 3))),
    if (is.finite(value)) shiny::tags$meter(min = 0, max = 1, value = value,
      "aria-label" = label, screen_ts_format(value, 3)))
  shiny::tagList(
    shiny::div(class = "strength-grid",
      meter("Seasonal strength", r$seasonal_strength), meter("Trend strength", r$trend_strength)),
    shiny::p(class = "result-footnote", "Strength indices range from 0 to 1; they are not probabilities."))
}

screen_ts_empty_result <- function(title, detail) {
  shiny::div(class = "result-empty", shiny::strong(title), shiny::p(detail))
}

screen_ts_result_table <- function(data, max_rows = 6L) {
  table <- function(d) shiny::div(class = "result-table-scroll",
    shiny::tags$table(class = "result-table",
      shiny::tags$thead(shiny::tags$tr(lapply(names(d), function(label)
        shiny::tags$th(scope = "col", label)))),
      shiny::tags$tbody(lapply(seq_len(nrow(d)), function(i)
        shiny::tags$tr(lapply(d, function(column) shiny::tags$td(column[i])))))))
  if (nrow(data) <= max_rows) return(table(data))
  shiny::tagList(table(utils::head(data, max_rows)),
    shiny::tags$details(class = "result-disclosure",
      shiny::tags$summary(paste("Show", nrow(data) - max_rows, "more")),
      table(data[-seq_len(max_rows), , drop = FALSE])))
}

screen_ts_outlier_results <- function(r, compact = FALSE) {
  if (is.na(r$n_outliers)) return(screen_ts_empty_result("Screening unavailable",
    "See the method notes for the requirements of this analysis."))
  if (!r$n_outliers) return(screen_ts_empty_result("No candidates detected",
    "The selected screening method did not flag any observations."))
  d <- r$outliers[[1]]
  if (compact) d <- utils::head(d, 4)
  shiny::tagList(
    if (!compact) shiny::div(class = "result-count", shiny::strong(r$n_outliers),
      shiny::span(if (r$n_outliers == 1) "candidate to inspect" else "candidates to inspect")),
    screen_ts_result_table(data.frame(
      Time = as.character(d$time), Value = vapply(d$value, screen_ts_format, character(1)),
      "Residual score" = vapply(d$score, screen_ts_format, character(1)), check.names = FALSE), max_rows = Inf),
    if (compact) shiny::actionButton("show_outliers",
      if (r$n_outliers > 4) paste("All", r$n_outliers, "candidates & method \u2197") else "Screening method \u2197",
      class = "link-btn") else
      shiny::p(class = "result-footnote", "Residual scores use the median absolute deviation (MAD). Candidate threshold: absolute score > 4.5; numerical tolerance is used when MAD is negligible."))
}

screen_ts_test_results <- function(r) {
  d <- r$tests[[1]]
  if (!nrow(d)) return(screen_ts_empty_result("Tests unavailable",
    "See the method notes for the data or package requirements."))
  shiny::tagList(shiny::div(class = "test-grid", lapply(seq_len(nrow(d)), function(i) {
    shiny::div(class = "test-result",
      shiny::div(class = "test-heading",
        shiny::h4(sub(" \\(observed values\\)", "", d$test[i])),
        shiny::span(class = "test-pvalue", paste("p =", screen_ts_format(d$p_value[i], 3)))),
      shiny::p(class = "test-conclusion", d$interpretation[i]),
      shiny::div(class = "test-assumption", paste("Null hypothesis:", d$null_hypothesis[i]),
        shiny::span(paste("Statistic", screen_ts_format(d$statistic[i])))))
  })), shiny::p(class = "result-footnote", "Exploratory tests at the 5% threshold. P-values may be bounded; non-rejection is not proof."))
}

screen_ts_correlation_metrics <- function(r, compact = FALSE) {
  d <- r$correlation[[1]]
  d <- d[d$lag > 0 & is.finite(d$acf), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  strongest <- which.max(abs(d$acf))
  lag_one <- d$acf[d$lag == 1]
  shiny::div(class = "metric-grid correlation-metrics",
    screen_ts_metric(if (compact) "Lag 1" else "Lag 1 correlation", screen_ts_format(lag_one, 3)),
    screen_ts_metric(if (compact) "Strongest lag" else "Strongest scanned lag", as.character(d$lag[strongest]),
      if (!compact) paste("ACF", screen_ts_format(d$acf[strongest], 3))),
    screen_ts_metric("Reference limits", paste("\u00b1", screen_ts_format(1.96 / sqrt(r$n), 3)),
      if (!compact) "Approximate 95% white-noise limits"))
}

screen_ts_break_results <- function(r) {
  if (is.na(r$n_breaks)) return(screen_ts_empty_result("Break detection unavailable",
    "See the method notes for the data or package requirements."))
  if (!r$n_breaks) return(screen_ts_empty_result("No change points selected",
    "BIC selected no breaks under this model."))
  d <- r$breakpoints[[1]]
  date_label <- function(x) ifelse(is.na(x), "\u2014", as.character(x))
  shiny::tagList(
    shiny::div(class = "result-count", shiny::strong(r$n_breaks),
      shiny::span(if (r$n_breaks == 1) "candidate change point" else "candidate change points")),
    screen_ts_result_table(data.frame(
      "Change point" = date_label(d$time), "95% lower" = date_label(d$lower),
      "95% upper" = date_label(d$upper), check.names = FALSE)),
    shiny::p(class = "result-footnote", "Confidence intervals are conditional on the model. Serial dependence can affect inference."))
}

screen_ts_method_notes <- function(r) {
  notes <- unique(r$notes[[1]])
  if (!length(notes)) return(NULL)
  shiny::tags$details(class = "method-notes",
    shiny::tags$summary("Method notes & limitations", shiny::span(class = "disclosure-hint", length(notes))),
    shiny::tags$ul(lapply(notes, shiny::tags$li)))
}
