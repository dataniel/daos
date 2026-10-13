# Internal preparation shared by the app and its tests. Store row numbers,
# not a copy of the data for every group. Tokens keep NA, dates and labels
# containing separators distinct throughout the round trip through Shiny.
screen_ts_result_code <- function(result) {
  if (is.null(result) || !nrow(result)) return(c("# No groups were flagged.", "flagged <- NULL"))
  columns <- lapply(seq_along(result), function(i) {
    value <- deparse(result[[i]], width.cutoff = 75L,
      control = c("keepNA", "keepInteger", "showAttributes"))
    lines <- c(paste0("  ", encodeString(names(result)[i], quote = '"'), " = ", value[1]),
               if (length(value) > 1L) paste0("    ", value[-1]))
    if (i < length(result)) lines[length(lines)] <- paste0(lines[length(lines)], ",")
    lines
  })
  c(paste0("# ", nrow(result), " flagged group(s). Copy this code to keep the result:"),
    "flagged <- tibble::tibble(", unlist(columns, use.names = FALSE), ")")
}

screen_ts_prepare <- function(data, x, y, by, series = NULL) {
  data <- tibble::as_tibble(dplyr::ungroup(data))
  if (!nrow(data)) cli::cli_abort("{.arg data} must contain at least one row.")
  cols <- c(x, y, by, series)
  if (!all(cols %in% names(data))) cli::cli_abort("Unknown time-series column.")
  if (!is.numeric(data[[y]])) cli::cli_abort("{.arg y} must be numeric.")
  if (any(vapply(data[cols], is.list, logical(1)))) {
    cli::cli_abort("Time-series columns must not be list columns.")
  }
  grouped <- dplyr::group_by(data, !!!rlang::syms(by), .drop = TRUE)
  keys <- dplyr::group_keys(grouped)
  rows <- lapply(dplyr::group_rows(grouped), function(i) {
    i[order(data[[x]][i], na.last = TRUE)]
  })
  values <- lapply(keys, unique)
  codes <- Map(match, keys, values)
  tokens <- do.call(paste, c(codes, sep = ":"))
  lookup <- new.env(hash = TRUE, parent = emptyenv())
  for (i in seq_along(tokens)) lookup[[tokens[i]]] <- i
  choices <- lapply(values, function(v) {
    labels <- as.character(v)
    labels[is.na(v)] <- "(missing)"
    stats::setNames(as.character(seq_along(v)), make.unique(labels))
  })
  list(data = data, keys = keys, rows = rows, codes = codes,
       members = lapply(codes, function(v) split(seq_along(v), v)),
       choices = choices, lookup = lookup)
}

# On sparse keys, honour the changed selector and keep as many of the other
# selections as possible. This lets users reach groups that require changing
# two dimensions without getting stuck on an impossible intermediate tuple.
screen_ts_resolve <- function(prepared, selected, current,
                             allowed = seq_len(nrow(prepared$keys))) {
  if (!length(allowed)) return(NA_integer_)
  found <- screen_ts_lookup(prepared, selected)
  if (!is.na(found) && found %in% allowed) return(found)
  values <- unlist(selected, use.names = FALSE)
  previous <- vapply(prepared$codes, function(v) as.character(v[current]), character(1))
  changed <- which(values != previous)
  if (!length(changed)) return(NA_integer_)
  candidates <- allowed
  for (j in changed) {
    rows <- prepared$members[[j]][[values[j]]]
    candidates <- intersect(candidates, rows)
    if (!length(candidates)) return(NA_integer_)
  }
  for (j in setdiff(seq_along(values), changed)) {
    preferred <- intersect(candidates, prepared$members[[j]][[previous[j]]])
    if (length(preferred)) candidates <- preferred
  }
  candidates[1]
}

screen_ts_lookup <- function(prepared, selected) {
  if (length(selected) != length(prepared$codes) ||
      any(lengths(selected) != 1L) || anyNA(unlist(selected))) return(NA_integer_)
  token <- paste(unlist(selected, use.names = FALSE), collapse = ":")
  found <- prepared$lookup[[token]]
  if (is.null(found)) NA_integer_ else found
}

screen_ts_validate_period <- function(period) {
  if (!is.null(period) && (length(period) != 1L || !is.numeric(period) ||
      !is.finite(period) || period < 1 || period != floor(period))) {
    cli::cli_abort("{.arg .period} must be NULL or a positive whole number.")
  }
  invisible(period)
}

# Infer a grid conservatively. Calendar months are not treated as 30 days.
# Gaps are counted on the inferred grid, never removed before modelling.
screen_ts_time_info <- function(x) {
  out <- list(interval = "Unknown", regular = FALSE, gaps = NA_real_, period = 1L)
  if (length(x) < 3L || anyNA(x) || anyDuplicated(x)) return(out)
  calendar <- inherits(x, c("Date", "POSIXt", "yearmonth", "yearquarter", "yearweek"))
  if (calendar) {
    dates <- as.Date(x)
    clock <- if (inherits(x, "POSIXt")) format(x, "%H:%M:%S") else rep("", length(x))
    month <- as.integer(format(dates, "%Y")) * 12L + as.integer(format(dates, "%m"))
    day <- as.integer(format(dates, "%d"))
    month_end <- format(dates + 1, "%d") == "01"
    if (length(unique(clock)) == 1L && all(diff(month) > 0) &&
        (length(unique(day)) == 1L || all(month_end))) {
      coordinate <- month
      unit <- "month(s)"
    } else if (length(unique(clock)) == 1L) {
      coordinate <- as.numeric(dates)
      unit <- "day(s)"
    } else {
      coordinate <- as.numeric(x)
      unit <- "second(s)"
    }
  } else if (is.numeric(x)) {
    coordinate <- as.numeric(x)
    unit <- "unit(s)"
  } else return(out)
  delta <- diff(coordinate)
  if (any(!is.finite(delta)) || any(delta <= 0)) return(out)
  step <- min(delta)
  multiples <- delta / step
  on_grid <- all(abs(multiples - round(multiples)) < 1e-6)
  out$interval <- paste(format(step, trim = TRUE), unit)
  out$gaps <- if (on_grid) sum(round(multiples) - 1) else NA_real_
  out$regular <- on_grid && out$gaps == 0
  if (unit == "month(s)" && step <= 12 && 12 %% step == 0) out$period <- 12 / step
  out
}

screen_ts_yaxis <- function(y, lower = NULL, upper = NULL) {
  axis <- list(title = "", gridcolor = "#f4f4f5", zeroline = FALSE,
               tickfont = list(color = "#71717a", size = 12))
  if (is.null(lower) && is.null(upper)) return(c(axis, list(autorange = TRUE)))
  limits <- if (any(is.finite(y))) range(y[is.finite(y)]) else c(0, 1)
  if (!all(is.finite(limits))) limits <- c(0, 1)
  padding <- if (diff(limits) > 0) diff(limits) * 0.05 else max(1, abs(limits[1]) * 0.05)
  limits <- limits + c(-padding, padding)
  if (!is.null(lower)) limits[1] <- lower
  if (!is.null(upper)) limits[2] <- upper
  if (limits[1] >= limits[2]) {
    if (is.null(upper)) limits[2] <- limits[1] + padding
    else if (is.null(lower)) limits[1] <- limits[2] - padding
  }
  c(axis, list(autorange = FALSE, range = limits))
}

screen_ts_plot <- function(data, x, y, series = NULL, title = NULL,
                           filename = "timeseries", lower = NULL, upper = NULL,
                           diagnostics = NULL, breaks = NULL, seasonality = FALSE) {
  palette <- c("#18181b", "#6366f1", "#10b981", "#f59e0b",
               "#ef4444", "#8b5cf6", "#06b6d4", "#ec4899")
  groups <- if (is.null(series)) list(seq_len(nrow(data))) else {
    split(seq_len(nrow(data)), match(data[[series]], unique(data[[series]])))
  }
  p <- plotly::plot_ly()
  for (i in seq_along(groups)) {
    d <- data[groups[[i]], , drop = FALSE]
    label <- if (is.null(series)) y else as.character(d[[series]][1])
    if (is.na(label)) label <- "(missing)"
    values <- d[[y]]
    values[!is.finite(values)] <- NA_real_
    p <- plotly::add_trace(p, x = d[[x]], y = values, type = "scatter",
      mode = if (nrow(d) <= 1500) "lines+markers" else "lines",
      name = label, showlegend = !is.null(series), connectgaps = FALSE,
      line = list(color = palette[(i - 1L) %% length(palette) + 1L], width = 1.5),
      marker = list(size = 4, color = palette[(i - 1L) %% length(palette) + 1L]),
      hovertemplate = "%{x}<br>%{y}<extra>%{fullData.name}</extra>")
  }
  if (!is.null(diagnostics) && nrow(diagnostics$outliers[[1]])) {
    outliers <- diagnostics$outliers[[1]]
    p <- plotly::add_trace(p, x = outliers$time, y = outliers$value,
      type = "scatter", mode = "markers", name = "Possible outlier",
      marker = list(color = "#ef4444", size = 10, symbol = "circle-open"),
      hovertemplate = "%{x}<br>%{y}<extra>Possible outlier</extra>", inherit = FALSE)
  }
  if (seasonality && !is.null(diagnostics) && diagnostics$period > 1 &&
      nrow(diagnostics$decomposition[[1]])) {
    d <- diagnostics$decomposition[[1]]
    p <- plotly::add_trace(p, x = d$time, y = d$trend + d$seasonal,
      type = "scatter", mode = "lines", name = "Trend + season",
      line = list(color = "#6366f1", width = 3, dash = "dash"),
      hovertemplate = "%{x}<br>%{y}<extra>Trend + season</extra>", inherit = FALSE)
  }
  shapes <- if (!is.null(breaks) && nrow(breaks$breakpoints[[1]])) {
    lapply(seq_len(nrow(breaks$breakpoints[[1]])), function(i) {
      at <- breaks$breakpoints[[1]]$time[i]
      list(type = "line", x0 = at, x1 = at, y0 = 0, y1 = 1,
           yref = "paper", line = list(color = "#f59e0b", dash = "dash"))
    })
  } else list()
  p <- plotly::layout(p, title = if (!is.null(title)) list(text = title, font = list(size = 14)) else NULL,
    font = list(family = "Inter, sans-serif", size = 12, color = "#52525b"),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    separators = ",.", margin = list(l = 65, r = 20, t = if (is.null(title)) 20 else 40, b = 40),
    xaxis = list(title = "", showgrid = FALSE, zeroline = FALSE),
    yaxis = screen_ts_yaxis(data[[y]], lower, upper),
    legend = list(orientation = "h", y = -0.16, x = 0, xanchor = "left"), shapes = shapes)
  plotly::config(p, displayModeBar = "hover",
    modeBarButtonsToRemove = list("select2d", "lasso2d"),
    toImageButtonOptions = list(format = "png", filename = filename))
}

screen_ts_season_plot <- function(result) {
  d <- result$decomposition[[1]]
  period <- result$period
  phase <- (seq_len(nrow(d)) - 1L) %% period + 1L
  labels <- as.character(seq_len(period))
  # Align calendar profiles even when a series starts halfway through a year.
  if (inherits(d$time, c("Date", "POSIXt", "yearmonth", "yearquarter")) &&
      ((period == 12 && result$interval == "1 month(s)") ||
       (period == 4 && result$interval == "3 month(s)"))) {
    month <- as.integer(format(as.Date(d$time), "%m"))
    phase <- if (period == 12) month else (month - 1L) %/% 3L + 1L
    labels <- if (period == 12) month.abb else paste0("Q", 1:4)
  }
  profile <- vapply(seq_len(period), function(i) mean(d$seasonal[phase == i]), numeric(1))
  plotly::plot_ly(x = seq_len(period), y = profile, type = "bar",
    marker = list(color = "#6366f1"), name = "Seasonal effect",
    text = labels, textposition = "none",
    hovertemplate = "%{text}<br>%{y}<extra>Seasonal effect</extra>") |>
    plotly::layout(showlegend = FALSE, paper_bgcolor = "rgba(0,0,0,0)",
      font = list(family = "Inter, sans-serif", size = 11, color = "#52525b"),
      plot_bgcolor = "rgba(0,0,0,0)", margin = list(l = 55, r = 10, t = 15, b = 55),
      xaxis = list(title = "Position in season", tickvals = seq_len(period), ticktext = labels),
      yaxis = list(title = "Effect in original units", gridcolor = "#f4f4f5")) |>
    plotly::config(displayModeBar = FALSE)
}

screen_ts_correlation_plot <- function(result) {
  d <- result$correlation[[1]]
  d <- d[d$lag > 0, , drop = FALSE]
  limit <- 1.96 / sqrt(result$n)
  panel <- function(values, title) {
    plotly::plot_ly(x = d$lag, y = values, type = "bar", name = title,
      marker = list(color = "#6366f1")) |>
      plotly::layout(showlegend = FALSE, xaxis = list(title = paste(title, "lag")),
        yaxis = list(title = "Correlation", range = c(-1, 1)),
        shapes = lapply(c(-limit, limit), function(y) list(type = "line",
          x0 = 0, x1 = 1, xref = "paper", y0 = y, y1 = y,
          line = list(dash = "dash", color = "#a1a1aa"))))
  }
  plotly::subplot(panel(d$acf, "ACF"), panel(d$pacf, "PACF"), titleX = TRUE, titleY = TRUE) |>
    plotly::layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      font = list(family = "Inter, sans-serif", size = 11, color = "#52525b"),
      annotations = list(list(text = "Dashed lines: approximate 95% white-noise limits",
        x = 0.5, y = 1.12, xref = "paper", yref = "paper", showarrow = FALSE))) |>
    plotly::config(displayModeBar = FALSE)
}
