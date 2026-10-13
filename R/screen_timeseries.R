#' Interactive time-series screening dashboard
#'
#' Launches a Shiny application for visually reviewing time-series data
#' group by group. All columns that are not `x`, `y`, `series`, or excluded
#' become grouping dimensions with dropdown selectors. Navigate between
#' groups with the arrow keys. Press `Space` to flag the current combination,
#' `R` to reset zoom, and `Q` to quit. Keys `1` to `6` toggle the diagnostic
#' tools in the order shown; shortcuts are displayed beside their controls.
#'
#' Requires the `shiny` and `plotly` packages. Diagnostic tools are selected
#' inside the app and all start switched off. Selected tools follow the
#' current group; results are cached within the session. With multiple lines,
#' choose which series to diagnose. Seasonality adds a trend-plus-season layer
#' and a seasonal profile; outliers and break dates overlay the main plot.
#' Tools live in the side panel. An integrated panel below the plot shows
#' findings and results one analysis at a time. Review scope filters select grouping values and
#' a time range; navigation and diagnostics use that scope. Existing flags are
#' retained, and returned flags still identify whole group combinations.
#' The full time range retains missing times; a narrowed range excludes them.
#'
#' @param data A data frame containing at minimum an x-axis column, a y-axis
#'   column, and at least one grouping column.
#' @param x Time (x-axis) variable. Accepts `Date`, `POSIXct`, numeric
#'   years, or calendar indices such as `tsibble::yearmonth`. (Unquoted.)
#' @param y Numeric measurement (y-axis) variable. (Unquoted.)
#' @param series Optional variable for plotting multiple lines per group
#'   (e.g. a category). (Unquoted.)
#' @param .exclude Columns to exclude from becoming grouping dropdowns.
#'   (Unquoted, tidy-select.)
#' @param .title Optional title string shown in the app header and in
#'   downloaded figures. The group combination (`a | b | c`) is always shown
#'   separately and is not affected.
#' @param .y_min Optional numeric. Pre-fills the Y min input, fixing the
#'   lower bound of the y-axis globally across all groups. Leave `NULL` for
#'   automatic scaling. Set to `0` to replicate the old "start at zero" behaviour.
#' @param .y_max Optional numeric. Pre-fills the Y max input, fixing the
#'   upper bound of the y-axis globally across all groups. Leave `NULL` for
#'   automatic scaling.
#' @param .period Optional seasonal period in observations. Pre-fills the
#'   app's seasonal-period control; `NULL` infers annual seasonality for
#'   calendar months/quarters and otherwise uses `1`. Can be changed in the app.
#'   See [daos::diagnose_timeseries()] for methods, requirements and limitations.
#' @param .print Print pasteable R code for the flagged groups on exit.
#'   Defaults to `TRUE`; set `FALSE` when only the invisible return is wanted.
#'   Printing also occurs when the function's return value is assigned.
#'
#' @return A data frame of flagged group combinations (the key columns only),
#'   or `NULL` if nothing was flagged. Returned invisibly when the app exits.
#'   Press `Q`, click Finish, or close the browser session to finish. When
#'   `.print = TRUE`, the console also receives a `flagged <- tibble::tibble(...)`
#'   expression preserving the grouping columns' types. Closing or reloading
#'   the browser session ends this local screening app.
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#'
#' # Simple example with economics dataset:
#' flagged <- ggplot2::economics_long |>
#'   dplyr::mutate(group = "Economics") |>
#'   screen_timeseries(date, value, series = variable, .exclude = value01)
#'
#' # With a grouping column:
#' df <- data.frame(
#'   year    = rep(2010:2020, 3),
#'   country = rep(c("DK", "SE", "NO"), each = 11),
#'   gdp     = rnorm(33, 300, 20)
#' )
#' flagged <- screen_timeseries(df, x = year, y = gdp)
#' }
#'
#' @importFrom cli cli_abort
#' @importFrom rlang enquo quo_is_null as_label syms
#' @importFrom dplyr select all_of
#' @export
screen_timeseries <- function(data, x, y, series = NULL, .exclude = NULL,
                        .title = NULL, .y_min = NULL, .y_max = NULL,
                        .period = NULL, .print = TRUE) {

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg shiny} is required for {.fn screen_timeseries}.")
  }
  if (!requireNamespace("plotly", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg plotly} is required for {.fn screen_timeseries}.")
  }

  x_var       <- rlang::enquo(x)
  y_var       <- rlang::enquo(y)
  series_var  <- rlang::enquo(series)
  exclude_var <- rlang::enquo(.exclude)

  has_series <- !rlang::quo_is_null(series_var)

  list_cols <- names(data)[vapply(data, is.list, logical(1))]
  if (length(list_cols) > 0) {
    data <- data |> dplyr::select(-dplyr::all_of(list_cols))
  }

  used_cols <- c(rlang::as_label(x_var), rlang::as_label(y_var))
  if (has_series) used_cols <- c(used_cols, rlang::as_label(series_var))

  excluded_cols <- character(0)
  if (!rlang::quo_is_null(exclude_var)) {
    excluded_cols <- data |> dplyr::select(!!exclude_var) |> names()
  }

  by_names <- setdiff(names(data), c(used_cols, excluded_cols))

  if (length(by_names) == 0) {
    cli::cli_abort(paste0(
      "No grouping columns found. Data must have at least one column ",
      "besides {.arg x}, {.arg y}, {.arg series}, and excluded columns."
    ))
  }

  screen_ts_validate_period(.period)
  if (!is.logical(.print) || length(.print) != 1L || is.na(.print)) {
    cli::cli_abort("{.arg .print} must be TRUE or FALSE.")
  }
  for (bound in list(.y_min, .y_max)) {
    if (!is.null(bound) && (length(bound) != 1L || !is.numeric(bound) || !is.finite(bound))) {
      cli::cli_abort("Axis limits must be NULL or finite numbers.")
    }
  }
  if (!is.null(.y_min) && !is.null(.y_max) && .y_min >= .y_max) {
    cli::cli_abort("{.arg .y_min} must be smaller than {.arg .y_max}.")
  }
  x_col <- rlang::as_name(x_var)
  y_col <- rlang::as_name(y_var)
  series_col <- if (has_series) rlang::as_name(series_var) else NULL
  prepared <- screen_ts_prepare(data, x_col, y_col, by_names, series_col)
  result <- shiny::runApp(screen_ts_app(prepared, x_col, y_col, series_col,
                                       .title, .y_min, .y_max, .period))
  if (.print) cat(paste(screen_ts_result_code(result), collapse = "\n"), "\n")
  invisible(result)
}

screen_ts_app <- function(prepared, x_col, y_col, series_col = NULL,
                          .title = NULL, .y_min = NULL, .y_max = NULL,
                          .period = NULL) {
  by_names <- names(prepared$keys)
  has_series <- !is.null(series_col)
  gid <- function(var) paste0("group_", match(var, by_names))
  time_scope <- screen_ts_time_scope(prepared$data[[x_col]])
  diagnostic_choices <- c("Statistics" = "summary", "Seasonality" = "seasonality",
    "Outliers" = "outliers", "Stationarity" = "stationarity",
    "Autocorrelation" = "autocorrelation", "Structural breaks" = "breaks")
  descriptions <- c("Level & spread", "Repeating patterns", "Unusual observations",
    "Stability over time", "Dependence across lags", "Changes in level or trend")
  diagnostic_input <- shiny::checkboxGroupInput("diagnostics", NULL,
    choiceNames = lapply(seq_along(diagnostic_choices), function(i) shiny::tagList(
      shiny::span(class = "tool-copy", shiny::span(names(diagnostic_choices)[i]),
        shiny::span(class = "tool-description", descriptions[i])),
      shiny::tags$kbd("aria-hidden" = "true", i))),
    choiceValues = unname(diagnostic_choices), selected = character(), inline = TRUE)

  dropdowns <- lapply(by_names, function(var) shiny::div(class = "field",
    shiny::tags$label(class = "field-label", "for" = paste0(gid(var), "-selectized"), var),
    shiny::selectizeInput(gid(var), label = NULL, choices = NULL, width = "100%")
  ))
  axis_input <- function(id, label, value) shiny::div(class = "field",
    shiny::tags$label(class = "field-label", "for" = id, label),
    shiny::tagAppendAttributes(
      shiny::numericInput(id, label = NULL, value = value, width = "100%"),
      .cssSelector = "input", placeholder = "Auto"))
  analysis <- function(feature, detail, metrics = NULL) shiny::div(class = "analysis-layout",
    shiny::div(class = "analysis-finding", shiny::uiOutput(paste0(feature, "_finding")), metrics),
    shiny::div(class = "analysis-detail", detail))
  chart <- function(id) shiny::div(class = "analysis-chart", plotly::plotlyOutput(id, height = "100%"))

  ui <- shiny::fluidPage(
    screen_ts_head(),
    shiny::div(class = "header",
      shiny::div(
        shiny::div(class = "header-eyebrow", "daos / screening"),
        shiny::h1(class = "header-title",
          if (!is.null(.title)) .title else "Time series screening")),
      shiny::div(class = "header-actions",
        shiny::div(class = "flag-count", role = "status", title = "All flagged groups, including those outside the current filters",
          shiny::textOutput("flag_count", inline = TRUE)),
        screen_ts_button("finish_btn", "Finish", "Q", class = "screen-btn-primary",
          title = "Finish screening and return flagged groups (Q)", "aria-keyshortcuts" = "Q"))
    ),
    shiny::div(class = "screen-workspace",
      shiny::tags$main(class = "screen-main",
        shiny::div(class = "control-bar",
          shiny::div(class = "field nav-field",
            shiny::div(class = "field-label", "Browse groups"),
            shiny::div(class = "nav-group", role = "group", "aria-label" = "Group navigation",
              shiny::actionButton("prev", "\u2190", class = "screen-btn nav-btn",
                title = "Previous group (Left arrow)", "aria-label" = "Previous group",
                "aria-keyshortcuts" = "ArrowLeft", disabled = "disabled"),
              shiny::div(class = "counter", role = "status", shiny::textOutput("counter", inline = TRUE)),
              shiny::actionButton("next_btn", "\u2192", class = "screen-btn nav-btn",
                title = "Next group (Right arrow)", "aria-label" = "Next group",
                "aria-keyshortcuts" = "ArrowRight"))),
          shiny::div(class = "group-fields", !!!dropdowns),
          shiny::actionButton("flag_btn", shiny::tagList(
            shiny::span(class = "flag-icon", "aria-hidden" = "true", "\u2605"),
            shiny::span(class = "button-label", "Flag group"),
            shiny::tags$kbd("aria-hidden" = "true", "Space")),
            class = "screen-btn flag-btn", title = "Flag this group (Space)",
            "aria-pressed" = "false", "aria-keyshortcuts" = "Space")
        ),
        shiny::div(class = "screen-plot-card",
          shiny::div(class = "plot-meta",
            shiny::div(class = "plot-meta-left",
              shiny::h2(class = "plot-title", shiny::textOutput("plot_title", inline = TRUE)),
              shiny::div(class = "plot-subtitle", shiny::textOutput("plot_subtitle", inline = TRUE))),
            shiny::div(class = "y-axis-controls",
              axis_input("y_min", "Y min", .y_min), axis_input("y_max", "Y max", .y_max),
              screen_ts_button("reset_zoom", "Reset zoom", "R",
                title = "Reset horizontal zoom (R)", "aria-keyshortcuts" = "R"))
          ),
          shiny::div(class = "plot-area", plotly::plotlyOutput("plot", height = "100%")),
          shiny::conditionalPanel("input.diagnostics && input.diagnostics.length > 0",
            class = "diagnostic-dock",
            shiny::actionButton("show_notes", "Method notes", class = "dock-notes link-btn"),
            shiny::tabsetPanel(id = "diagnostic_view", type = "tabs", selected = "overview",
              shiny::tabPanel("Overview", value = "overview", shiny::uiOutput("diagnostic_findings")),
              shiny::tabPanel("Statistics", value = "summary",
                analysis("summary", shiny::uiOutput("summary_metrics"))),
              shiny::tabPanel("Seasonality", value = "seasonality",
                analysis("seasonality", chart("season_plot"), shiny::uiOutput("season_metrics"))),
              shiny::tabPanel("Outliers", value = "outliers",
                analysis("outliers", shiny::uiOutput("outlier_results"))),
              shiny::tabPanel("Stationarity", value = "stationarity",
                analysis("stationarity", shiny::uiOutput("stationarity_results"))),
              shiny::tabPanel("Autocorrelation", value = "autocorrelation",
                analysis("autocorrelation", chart("correlation_plot"), shiny::uiOutput("correlation_metrics"))),
              shiny::tabPanel("Breaks", value = "breaks",
                analysis("breaks", shiny::uiOutput("break_results")))))
        )
      ),
      shiny::tags$aside(class = "screen-sidebar", "aria-label" = "Review settings",
        shiny::tags$details(id = "scope-panel", class = "scope-tools",
          shiny::tags$summary(
            shiny::span(shiny::span("Review scope"),
              shiny::span(class = "scope-caption", shiny::textOutput("scope_count", inline = TRUE))),
            shiny::span(class = "sidebar-chevron", "aria-hidden" = "true", "\u2304")),
          shiny::div(class = "scope-body",
            shiny::p(class = "sidebar-intro", "Choose groups and a period to review."),
            lapply(seq_along(by_names), function(i) shiny::div(class = "field",
              shiny::selectizeInput(paste0("scope_", i), by_names[i], choices = NULL,
                multiple = TRUE, width = "100%",
                options = list(placeholder = "All groups", plugins = list("remove_button"))))),
            if (time_scope$enabled) shiny::sliderInput("time_scope", "Time range",
              min = time_scope$bounds[1], max = time_scope$bounds[2], value = time_scope$bounds,
              step = if (inherits(time_scope$bounds, "Date")) 1 else NULL,
              ticks = FALSE, width = "100%"),
            shiny::actionButton("reset_scope", "Reset filters", class = "screen-btn scope-reset"),
            shiny::p(class = "field-help", "Flags are kept when you change the filters."))
        ),
        shiny::tags$details(id = "diagnostic-panel", class = "diagnostic-tools", open = "open",
          shiny::tags$summary(
            shiny::span(id = "diagnostics-heading", "Diagnostic tools"),
            shiny::span(class = "sidebar-chevron", "aria-hidden" = "true", "\u2304")),
          shiny::p(class = "sidebar-intro", "Add a second perspective to your review."),
          shiny::tags$div(role = "group", "aria-labelledby" = "diagnostics-heading", diagnostic_input),
          shiny::conditionalPanel("input.diagnostics && input.diagnostics.length > 0",
            shiny::div(class = "diagnostic-controls",
              if (has_series) shiny::selectInput("diagnostic_series", "Series to diagnose", choices = NULL),
              shiny::conditionalPanel("input.diagnostics && (input.diagnostics.indexOf('seasonality') >= 0 || input.diagnostics.indexOf('outliers') >= 0 || input.diagnostics.indexOf('breaks') >= 0)",
                shiny::numericInput("diagnostic_period", "Seasonal period",
                  value = if (is.null(.period)) NA_real_ else .period, min = 1, step = 1),
                shiny::p(class = "field-help", "Leave blank to infer from the time index.")),
              shiny::conditionalPanel("input.diagnostics && input.diagnostics.indexOf('breaks') >= 0",
                shiny::selectInput("break_type", "Break model", c("Level" = "level", "Trend" = "trend")))
            ),
            shiny::div(class = "diagnostic-context", shiny::textOutput("diagnostic_context"))
          )
        )
      )
    )
  )
  shiny::shinyApp(ui, screen_ts_server(prepared, x_col, y_col, series_col, .title))
}
