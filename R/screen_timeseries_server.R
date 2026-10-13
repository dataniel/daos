screen_ts_server <- function(prepared, x_col, y_col, series_col = NULL,
                             .title = NULL) {
  keys <- prepared$keys
  data <- prepared$data
  by_names <- names(keys)
  has_series <- !is.null(series_col)
  series_values <- if (has_series) unique(data[[series_col]]) else NULL
  gid <- function(var) paste0("group_", match(var, by_names))
  time_scope <- screen_ts_time_scope(data[[x_col]])
  function(input, output, session) {
    idx <- shiny::reactiveVal(1L)
    flagged <- shiny::reactiveVal(integer())
    scoped_rows <- shiny::reactive(screen_ts_scope_rows(prepared, time_scope, input$time_scope))
    scoped_indices <- shiny::reactive(screen_ts_scope_indices(prepared,
      lapply(seq_along(by_names), function(i) input[[paste0("scope_", i)]]), scoped_rows()))
    current_rows <- shiny::reactive({
      shiny::validate(shiny::need(idx() %in% scoped_indices(),
        "No groups match these filters. Adjust the review scope or reset the filters."))
      scoped_rows()[[idx()]]
    })
    current_data <- shiny::reactive(data[current_rows(), , drop = FALSE])
    current_key <- shiny::reactive(keys[idx(), , drop = FALSE])
    key_label <- shiny::reactive(paste(vapply(current_key(), function(v) {
      if (is.na(v)) "(missing)" else as.character(v)
    }, character(1)), collapse = " | "))
    flagged_keys <- shiny::reactive({
      f <- flagged()
      if (length(f)) keys[sort(f), , drop = FALSE] else NULL
    })
    finished <- FALSE
    finish <- function() {
      if (!finished) {
        finished <<- TRUE
        shiny::stopApp(shiny::isolate(flagged_keys()))
      }
    }
    session$onSessionEnded(finish)
    shiny::observeEvent(TRUE, {
      for (j in seq_along(by_names)) shiny::updateSelectizeInput(session, paste0("scope_", j),
        choices = prepared$choices[[j]], selected = character(), server = TRUE)
    }, once = TRUE)
    shiny::observeEvent(input$reset_scope, {
      for (j in seq_along(by_names)) shiny::updateSelectizeInput(session, paste0("scope_", j),
        selected = character())
      if (time_scope$enabled) shiny::updateSliderInput(session, "time_scope", value = time_scope$bounds)
    }, ignoreInit = TRUE)
    sync_dropdowns <- function(i, allowed = scoped_indices()) {
      for (var in by_names) {
        shiny::freezeReactiveValue(input, gid(var))
        # A server-side update replaces the option source, even when choices
        # is NULL. Keep the complete source so navigation cannot empty it.
        shiny::updateSelectizeInput(session, gid(var),
          choices = prepared$choices[[var]][prepared$choices[[var]] %in% as.character(prepared$codes[[var]][allowed])],
          selected = if (i %in% allowed) as.character(prepared$codes[[var]][i]) else character(), server = TRUE)
      }
    }
    shiny::observe({
      allowed <- scoped_indices()
      i <- idx()
      if (length(allowed) && !i %in% allowed) {
        idx(allowed[1])
      } else sync_dropdowns(i, allowed)
    })
    shiny::observeEvent(lapply(by_names, function(var) input[[gid(var)]]), {
      selected <- lapply(by_names, function(var) input[[gid(var)]])
      if (any(lengths(selected) != 1L)) return()
      # Server-side selectize starts empty while loading its first options.
      if (any(!nzchar(unlist(selected)))) return()
      if (!length(scoped_indices())) return()
      next_idx <- screen_ts_resolve(prepared, selected, idx(), scoped_indices())
      if (is.na(next_idx)) {
        shiny::showNotification("No observations for this combination. Restored the current group.",
          type = "message", id = "missing_group")
        sync_dropdowns(idx())
      } else if (next_idx != idx()) idx(next_idx)
    })
    move_group <- function(step) {
      allowed <- scoped_indices()
      position <- match(idx(), allowed)
      if (!length(allowed) || is.na(position)) return()
      idx(allowed[max(1L, min(length(allowed), position + step))])
    }
    shiny::observeEvent(input$prev, move_group(-1L), ignoreInit = TRUE)
    shiny::observeEvent(input$next_btn, move_group(1L), ignoreInit = TRUE)
    shiny::observeEvent(input$flag_btn, {
      i <- idx()
      if (!i %in% scoped_indices()) return()
      flagged(if (i %in% flagged()) setdiff(flagged(), i) else union(flagged(), i))
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$exit_key, finish(), ignoreInit = TRUE)
    shiny::observeEvent(input$finish_btn, finish(), ignoreInit = TRUE)
    shiny::observeEvent(input$reset_zoom, {
      plotly::plotlyProxy("plot", session) |>
        plotly::plotlyProxyInvoke("relayout", list("xaxis.autorange" = TRUE))
    }, ignoreInit = TRUE)
    shiny::observe({
      position <- match(idx(), scoped_indices())
      session$sendCustomMessage("screen_state", list(
        first = is.na(position) || position == 1L,
        last = is.na(position) || position == length(scoped_indices()),
        empty = is.na(position), flagged = !is.na(position) && idx() %in% flagged()))
    })
    features <- shiny::reactive(sort(as.character(input$diagnostics)))
    previous_features <- character()
    shiny::observeEvent(features(), {
      enabled <- features()
      for (feature in c("summary", "seasonality", "outliers", "stationarity", "autocorrelation", "breaks")) {
        if (feature %in% enabled) shiny::showTab("diagnostic_view", feature, session = session)
        else shiny::hideTab("diagnostic_view", feature, session = session)
      }
      added <- setdiff(enabled, previous_features)
      current <- shiny::isolate(input$diagnostic_view)
      selected <- if (length(added)) utils::tail(added, 1) else if (length(current) && current %in% enabled) current else "overview"
      previous_features <<- enabled
      shiny::updateTabsetPanel(session, "diagnostic_view", selected = selected)
    }, ignoreNULL = FALSE)
    selected_series <- shiny::reactive({
      if (!has_series) return(0L)
      available <- match(unique(current_data()[[series_col]]), series_values)
      selected <- suppressWarnings(as.integer(input$diagnostic_series))
      if (length(selected) == 1L && selected %in% available) selected else available[1]
    })
    if (has_series) shiny::observeEvent(list(idx(), scoped_rows()), {
      available <- match(unique(current_data()[[series_col]]), series_values)
      labels <- as.character(series_values[available])
      labels[is.na(series_values[available])] <- "(missing)"
      shiny::updateSelectInput(session, "diagnostic_series",
        choices = stats::setNames(as.character(available), make.unique(labels)),
        selected = as.character(selected_series()))
    })
    diagnostic_period <- shiny::reactive({
      if (!any(c("seasonality", "outliers", "breaks") %in% features())) return(NULL)
      p <- input$diagnostic_period
      if (is.null(p) || is.na(p)) return(NULL)
      shiny::validate(shiny::need(is.finite(p) && p >= 1 && p == floor(p),
                                  "Seasonal period must be a positive whole number."))
      p
    })
    break_type <- shiny::reactive({
      if (!"breaks" %in% features()) return("none")
      if (identical(input$break_type, "trend")) "trend" else "level"
    })
    diagnostic_data <- shiny::reactive({
      d <- current_data()
      if (has_series) d <- d[match(d[[series_col]], series_values) == selected_series(), , drop = FALSE]
      d
    })
    cached_diagnostics <- shiny::bindCache(shiny::reactive({
      d <- diagnostic_data()
      screen_ts_diagnose(d[[x_col]], d[[y_col]], diagnostic_period(),
        break_type(), setdiff(features(), "breaks"))
    }), idx(), current_rows(), selected_series(), diagnostic_period(), features(), break_type(), cache = "session")
    diagnostics <- shiny::reactive({
      shiny::req(length(features()) > 0)
      cached_diagnostics()
    })
    nullify <- function(v) if (is.null(v) || !length(v) || is.na(v)) NULL else v
    axis_limits <- shiny::reactive({
      lower <- nullify(input$y_min)
      upper <- nullify(input$y_max)
      shiny::validate(shiny::need(is.null(lower) || is.null(upper) || lower < upper,
                                  "Y min must be smaller than Y max."))
      list(lower = lower, upper = upper)
    })
    shiny::observeEvent(list(input$y_min, input$y_max), {
      limits <- axis_limits()
      axis <- screen_ts_yaxis(current_data()[[y_col]], limits$lower, limits$upper)
      changes <- list("yaxis.autorange" = axis$autorange)
      if (!is.null(axis$range)) changes[["yaxis.range"]] <- axis$range
      plotly::plotlyProxy("plot", session) |> plotly::plotlyProxyInvoke("relayout", changes)
    }, ignoreInit = TRUE)
    output$counter <- shiny::renderText({
      position <- match(idx(), scoped_indices())
      paste0(if (is.na(position)) 0L else position, " / ", length(scoped_indices()))
    })
    output$scope_count <- shiny::renderText({
      bounds <- as.numeric(input$time_scope)
      narrowed <- time_scope$enabled && length(bounds) == 2L && all(is.finite(bounds)) &&
        !isTRUE(all.equal(bounds, as.numeric(time_scope$bounds)))
      paste0(length(scoped_indices()), " of ", nrow(keys), " groups",
        if (narrowed) " | filtered period" else "")
    })
    output$flag_count <- shiny::renderText(paste(length(flagged()), "flagged"))
    output$plot_title <- shiny::renderText(if (length(scoped_indices())) key_label() else "No groups in this view")
    output$plot_subtitle <- shiny::renderText({
      if (!length(scoped_indices())) return("Adjust the review scope to continue screening.")
      d <- current_data()
      if (!has_series) return(paste(nrow(d), "observations"))
      counts <- tabulate(match(d[[series_col]], unique(d[[series_col]])))
      r <- range(counts)
      paste0(length(counts), " series | ",
        if (r[1] == r[2]) paste(r[1], "observations each") else paste0(r[1], "-", r[2], " observations"))
    })
    output$plot <- plotly::renderPlotly({
      overlay <- NULL
      if (any(c("seasonality", "outliers", "breaks") %in% features())) {
        overlay <- tryCatch(diagnostics(), shiny.silent.error = function(e) NULL)
      }
      limits <- shiny::isolate(axis_limits())
      screen_ts_plot(current_data(), x_col, y_col, series_col,
        title = .title, filename = gsub("[^[:alnum:]_.-]+", "_", key_label()),
        lower = limits$lower, upper = limits$upper,
        diagnostics = overlay, breaks = if ("breaks" %in% features()) overlay else NULL,
        seasonality = "seasonality" %in% features())
    })
    diagnostic_label <- shiny::reactive({
      label <- if (!has_series) y_col else as.character(series_values[selected_series()])
      if (is.na(label)) "(missing)" else label
    })
    output$diagnostic_context <- shiny::renderText({
      r <- diagnostics()
      paste0(r$n, " observations | Interval: ", r$interval, " | Period: ", r$period)
    })
    output$diagnostic_findings <- shiny::renderUI(
      screen_ts_insights(diagnostics(), features(), diagnostic_label(), compact = TRUE))
    for (feature in c("summary", "seasonality", "outliers", "stationarity", "autocorrelation", "breaks")) local({
      selected_feature <- feature
      output[[paste0(selected_feature, "_finding")]] <- shiny::renderUI({
        shiny::req(selected_feature %in% features())
        screen_ts_finding(diagnostics(), selected_feature, diagnostic_label())
      })
    })
    output$summary_metrics <- shiny::renderUI({
      shiny::req("summary" %in% features())
      screen_ts_overview(diagnostics(), compact = TRUE)
    })
    output$season_metrics <- shiny::renderUI({
      shiny::req("seasonality" %in% features())
      screen_ts_strengths(diagnostics())
    })
    output$outlier_results <- shiny::renderUI({
      shiny::req("outliers" %in% features())
      screen_ts_outlier_results(diagnostics(), compact = TRUE)
    })
    output$stationarity_results <- shiny::renderUI({
      shiny::req("stationarity" %in% features())
      screen_ts_test_results(diagnostics())
    })
    output$correlation_metrics <- shiny::renderUI({
      shiny::req("autocorrelation" %in% features())
      screen_ts_correlation_metrics(diagnostics(), compact = TRUE)
    })
    output$break_results <- shiny::renderUI({
      shiny::req("breaks" %in% features())
      screen_ts_break_results(diagnostics())
    })
    shiny::observeEvent(input$show_quality, {
      shiny::showModal(shiny::modalDialog(title = paste("Data quality -", diagnostic_label()),
        screen_ts_quality(diagnostics()), easyClose = TRUE, footer = shiny::modalButton("Close")))
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$show_outliers, {
      shiny::showModal(shiny::modalDialog(title = paste("Outlier screening -", diagnostic_label()),
        screen_ts_outlier_results(diagnostics()), easyClose = TRUE, footer = shiny::modalButton("Close")))
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$show_notes, {
      notes <- unique(diagnostics()$notes[[1]])
      shiny::showModal(shiny::modalDialog(title = "Method notes & limitations",
        shiny::div(class = "notes-content",
          if (length(notes)) shiny::tags$ul(lapply(notes, shiny::tags$li)) else
            shiny::p("No additional method notes for this view.")),
        easyClose = TRUE, footer = shiny::modalButton("Close")))
    }, ignoreInit = TRUE)
    output$season_plot <- plotly::renderPlotly({
      shiny::req("seasonality" %in% features())
      r <- diagnostics()
      shiny::validate(shiny::need(r$period > 1, "Choose a seasonal period greater than 1."),
        shiny::need(nrow(r$decomposition[[1]]) > 0, "Seasonal profile unavailable; see the method notes."))
      screen_ts_season_plot(r)
    })
    output$correlation_plot <- plotly::renderPlotly({
      shiny::req("autocorrelation" %in% features())
      r <- diagnostics()
      shiny::validate(shiny::need(nrow(r$correlation[[1]]) > 0,
        "Correlations unavailable; see the method notes."))
      screen_ts_correlation_plot(r)
    })
  }
}
