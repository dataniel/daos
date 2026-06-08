#' Interactive time-series screening dashboard
#'
#' Launches a Shiny application for visually reviewing time-series data
#' group by group. All columns that are not `x`, `y`, `series`, or excluded
#' become grouping dimensions with dropdown selectors. Navigate between
#' groups with the arrow keys. Press `Space` to flag the current combination,
#' `R` to reset zoom, and `Q` to quit.
#'
#' Requires the `shiny`, `ggplot2`, and `plotly` packages.
#'
#' @param data A data frame containing at minimum an x-axis column, a y-axis
#'   column, and at least one grouping column.
#' @param x Time (x-axis) variable. Accepts `Date`, `POSIXct`, numeric
#'   years, or any value coercible to a date. (Unquoted.)
#' @param y Numeric measurement (y-axis) variable. (Unquoted.)
#' @param series Optional variable for plotting multiple lines per group
#'   (e.g. a category). (Unquoted.)
#' @param .exclude Columns to exclude from becoming grouping dropdowns.
#'   (Unquoted, tidy-select.)
#' @param .title Optional title string shown in the app header and in
#'   downloaded figures. The group combination (`a · b · c`) is always shown
#'   separately and is not affected.
#' @param .y_min Optional numeric. Pre-fills the Y min input, fixing the
#'   lower bound of the y-axis globally across all groups. Leave `NULL` for
#'   automatic scaling. Set to `0` to replicate the old "start at zero" behaviour.
#' @param .y_max Optional numeric. Pre-fills the Y max input, fixing the
#'   upper bound of the y-axis globally across all groups. Leave `NULL` for
#'   automatic scaling.
#'
#' @return A data frame of flagged group combinations (the key columns only),
#'   or `NULL` if nothing was flagged. Returned invisibly when the app exits.
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#'
#' # Simple example with economics dataset:
#' flagged <- ggplot2::economics_long |>
#'   screen_timeseries(date, value, series = variable)
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
#' @importFrom purrr map_lgl map walk map_chr map2
#' @importFrom dplyr select all_of group_by group_keys semi_join arrange pull group_split
#' @export
screen_timeseries <- function(data, x, y, series = NULL, .exclude = NULL,
                        .title = NULL, .y_min = NULL, .y_max = NULL) {

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

  list_cols <- names(data)[purrr::map_lgl(data, is.list)]
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

  by <- rlang::syms(by_names)

  keys <- data |>
    dplyr::group_by(!!!by) |>
    dplyr::group_keys()

  dropdowns <- purrr::map(by_names, \(var) {
    choices <- as.character(unique(keys[[var]]))
    shiny::div(
      class = "field",
      shiny::tags$label(class = "field-label", var),
      shiny::selectInput(
        inputId = paste0("group_", var),
        label   = NULL,
        choices = as.list(choices),
        width   = "100%"
      )
    )
  })

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$link(
        rel  = "stylesheet",
        href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
      ),
      shiny::tags$style(shiny::HTML("
        body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
               background: #f7f7f8; color: #18181b; margin: 0;
               -webkit-font-smoothing: antialiased; }
        .container-fluid { max-width: 1280px; margin: 0 auto; padding: 40px 24px; }
        .header { margin-bottom: 24px; display: flex; align-items: center;
                  justify-content: space-between; }
        .header-title { font-size: 13px; font-weight: 600; color: #71717a;
                        text-transform: uppercase; letter-spacing: 0.08em; }
        .header-hint { font-size: 12px; color: #a1a1aa; font-weight: 500; }
        .header-hint kbd { font-family: 'Inter', sans-serif; font-size: 11px;
                           font-weight: 600; padding: 2px 6px; background: white;
                           border: 1px solid #e4e4e7; border-radius: 4px;
                           color: #52525b; margin: 0 2px; }
        .control-bar { display: flex; align-items: flex-end; gap: 16px;
                       padding: 20px; background: white; border: 1px solid #e4e4e7;
                       border-radius: 12px; margin-bottom: 24px; flex-wrap: wrap;
                       box-shadow: 0 1px 2px rgba(0,0,0,0.04); }
        .nav-group { display: flex; align-items: center; gap: 8px; height: 38px; }
        .nav-btn { width: 38px; height: 38px; border: 1px solid #e4e4e7;
                   background: white; border-radius: 8px; font-size: 14px;
                   color: #52525b; cursor: pointer; transition: all 0.15s ease;
                   padding: 0; display: flex; align-items: center;
                   justify-content: center; }
        .nav-btn:hover { background: #fafafa; border-color: #d4d4d8; color: #18181b; }
        .nav-btn:active { transform: scale(0.96); }
        .nav-btn.active { background: #fef3c7; border-color: #f59e0b; color: #d97706; }
        .counter { font-size: 13px; font-weight: 500; color: #71717a;
                   min-width: 56px; text-align: center;
                   font-variant-numeric: tabular-nums; }
        .field { display: flex; flex-direction: column; gap: 6px; min-width: 140px; }
        .field-label { font-size: 11px; font-weight: 600; color: #71717a;
                       text-transform: uppercase; letter-spacing: 0.06em;
                       margin: 0; line-height: 1; }
        .field .form-group { margin: 0; }
        .field .form-control { background: white; border-radius: 8px;
                                border: 1px solid #e4e4e7; height: 38px;
                                font-size: 14px; color: #18181b; padding: 0 12px;
                                font-family: inherit; font-weight: 500; }
        .field .form-control:focus { border-color: #a1a1aa;
                                      box-shadow: 0 0 0 3px rgba(161,161,170,0.15);
                                      outline: none; }
        .plot-container { background: white; border: 1px solid #e4e4e7;
                          border-radius: 12px; padding: 28px 28px 20px;
                          box-shadow: 0 1px 2px rgba(0,0,0,0.04); }
        .plot-meta { display: flex; align-items: center; gap: 12px;
                     margin-bottom: 20px; padding-bottom: 16px;
                     border-bottom: 1px solid #f4f4f5; }
        .plot-meta-left { flex: 1; display: flex; align-items: center; gap: 12px; }
        .plot-title { font-size: 16px; font-weight: 600; color: #18181b; margin: 0; }
        .plot-subtitle { font-size: 13px; color: #71717a; font-weight: 500; }
        .y-axis-controls { display: flex; align-items: flex-end; gap: 8px;
                           margin-left: auto; flex-shrink: 0; }
        .y-axis-controls .field { min-width: 72px; max-width: 88px; }
        .y-axis-controls .field-label { font-size: 10px; }
        .y-axis-controls .form-group { margin: 0; }
        .y-axis-controls .form-control { height: 30px; font-size: 13px;
                                          padding: 0 8px; border-radius: 6px; }
      ")),
      shiny::tags$script(shiny::HTML("
        $(document).keydown(function(e) {
          if (e.key === 'Escape') {
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA'
                || e.target.tagName === 'SELECT') { e.target.blur(); }
            return;
          }
          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA'
              || e.target.tagName === 'SELECT') return;
          if (e.key === 'ArrowLeft')  $('#prev').click();
          if (e.key === 'ArrowRight') $('#next_btn').click();
          if (e.key === ' ') { e.preventDefault(); $('#flag_btn').click(); }
          if (e.key === 'r' || e.key === 'R') Shiny.setInputValue('reset_zoom', Math.random(), {priority: 'event'});
          if (e.key === 'q' || e.key === 'Q') Shiny.setInputValue('exit_key',   Math.random());
        });
        Shiny.addCustomMessageHandler('toggle_class', function(msg) {
          if (msg.active) { $(msg.selector).addClass(msg.cls); }
          else            { $(msg.selector).removeClass(msg.cls); }
        });
      "))
    ),
    shiny::div(class = "header",
      shiny::div(class = "header-title",
        if (!is.null(.title)) .title else "Time series screening"
      ),
      shiny::div(class = "header-hint",
        shiny::tags$kbd("←"), "/", shiny::tags$kbd("→"), " navigate  ",
        shiny::tags$kbd("Space"), " flag  ",
        shiny::tags$kbd("R"), " reset zoom  ",
        shiny::tags$kbd("Q"), " quit"
      )
    ),
    shiny::div(class = "control-bar",
      shiny::div(class = "nav-group",
        shiny::tags$button(id = "prev",     class = "nav-btn action-button", "←"),
        shiny::div(class = "counter", shiny::textOutput("counter", inline = TRUE)),
        shiny::tags$button(id = "next_btn", class = "nav-btn action-button", "→"),
        shiny::tags$button(id = "flag_btn", class = "nav-btn action-button", "★")
      ),
      !!!dropdowns
    ),
    shiny::div(class = "plot-container",
      shiny::div(class = "plot-meta",
        shiny::div(class = "plot-meta-left",
          shiny::h2(class = "plot-title",
                    shiny::textOutput("plot_title", inline = TRUE)),
          shiny::div(class = "plot-subtitle",
                     shiny::textOutput("plot_subtitle", inline = TRUE))
        ),
        shiny::div(class = "y-axis-controls",
          shiny::div(class = "field",
            shiny::tags$label(class = "field-label", "Y min"),
            shiny::numericInput("y_min", label = NULL, value = .y_min, width = "100%")
          ),
          shiny::div(class = "field",
            shiny::tags$label(class = "field-label", "Y max"),
            shiny::numericInput("y_max", label = NULL, value = .y_max, width = "100%")
          )
        )
      ),
      plotly::plotlyOutput("plot", height = "480px")
    )
  )

  server <- function(input, output, session) {
    idx     <- shiny::reactiveVal(1L)
    flagged <- shiny::reactiveVal(integer(0))

    shiny::observeEvent(input$exit_key, {
      f <- flagged()
      result <- if (length(f) > 0) keys[sort(f), , drop = FALSE] else NULL
      shiny::stopApp(result)
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$flag_btn, {
      i       <- idx()
      current <- flagged()
      flagged(if (i %in% current) setdiff(current, i) else union(current, i))
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$reset_zoom, {
      plotly::plotlyProxy("plot", session) |>
        plotly::plotlyProxyInvoke("relayout", list("xaxis.autorange" = TRUE))
    }, ignoreInit = TRUE)

    shiny::observe({
      session$sendCustomMessage("toggle_class", list(
        selector = "#flag_btn", cls = "active", active = idx() %in% flagged()
      ))
    })

    y_min_val <- shiny::reactive({ v <- input$y_min; if (is.null(v) || is.na(v)) NULL else v })
    y_max_val <- shiny::reactive({ v <- input$y_max; if (is.null(v) || is.na(v)) NULL else v })

    sync_dropdowns <- function(new_idx) {
      current_key <- keys[new_idx, , drop = FALSE]
      for (var in by_names) {
        shiny::updateSelectInput(session, paste0("group_", var),
                                 selected = as.character(current_key[[var]]))
      }
    }

    find_idx <- function() {
      current_values <- purrr::map_chr(by_names, \(var) {
        val <- input[[paste0("group_", var)]]
        if (is.null(val)) NA_character_ else as.character(val)
      })
      matches <- purrr::map_lgl(seq_len(nrow(keys)), \(i) {
        all(as.character(unlist(keys[i, ])) == current_values)
      })
      which(matches)[1]
    }

    shiny::observeEvent(input$prev, {
      new_idx <- max(1L, idx() - 1L); idx(new_idx); sync_dropdowns(new_idx)
    })
    shiny::observeEvent(input$next_btn, {
      new_idx <- min(nrow(keys), idx() + 1L); idx(new_idx); sync_dropdowns(new_idx)
    })

    purrr::walk(by_names, \(var) {
      shiny::observeEvent(input[[paste0("group_", var)]], {
        new_idx <- find_idx()
        if (!is.na(new_idx) && new_idx != idx()) idx(new_idx)
      }, ignoreInit = TRUE)
    })

    current_data <- shiny::reactive({
      target <- keys[idx(), , drop = FALSE]
      data |>
        dplyr::semi_join(target, by = names(target)) |>
        dplyr::arrange(!!x_var)
    })

    current_key <- shiny::reactive({ keys[idx(), , drop = FALSE] })

    output$counter <- shiny::renderText({
      n_flagged <- length(flagged())
      flag_str  <- if (n_flagged > 0) paste0("  ★", n_flagged) else ""
      paste0(idx(), " / ", nrow(keys), flag_str)
    })
    output$plot_title <- shiny::renderText({
      paste(as.character(unlist(current_key())), collapse = " · ")
    })
    output$plot_subtitle <- shiny::renderText({
      d <- current_data()
      if (has_series) {
        counts    <- tapply(seq_len(nrow(d)), dplyr::pull(d, !!series_var), length)
        n_series  <- length(counts)
        obs_range <- range(counts)
        obs_str   <- if (obs_range[1] == obs_range[2]) {
          paste0(obs_range[1], " observations each")
        } else {
          paste0(obs_range[1], "–", obs_range[2], " observations")
        }
        paste0(n_series, " series · ", obs_str)
      } else {
        n_obs <- nrow(d)
        paste0(n_obs, " observation", if (n_obs == 1) "" else "s")
      }
    })

    output$plot <- plotly::renderPlotly({
      d       <- current_data()
      palette <- c("#18181b", "#6366f1", "#10b981", "#f59e0b",
                   "#ef4444", "#8b5cf6", "#06b6d4", "#ec4899")

      if (has_series) {
        unique_series <- as.character(unique(dplyr::pull(d, !!series_var)))
        colors <- setNames(rep_len(palette, length(unique_series)), unique_series)
        p <- ggplot2::ggplot(d, ggplot2::aes(
          x     = !!x_var,
          y     = !!y_var,
          color = as.character(!!series_var),
          group = as.character(!!series_var)
        )) +
          ggplot2::geom_line(linewidth = 0.8) +
          ggplot2::geom_point(size = 1.5) +
          ggplot2::scale_color_manual(values = colors)
      } else {
        p <- ggplot2::ggplot(d, ggplot2::aes(x = !!x_var, y = !!y_var)) +
          ggplot2::geom_line(color = "#18181b", linewidth = 0.8) +
          ggplot2::geom_point(color = "#18181b", size = 1.5)
      }

      p <- p +
        ggplot2::theme_minimal() +
        ggplot2::theme(
          plot.background    = ggplot2::element_blank(),
          panel.background   = ggplot2::element_blank(),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.minor   = ggplot2::element_blank(),
          panel.grid.major.y = ggplot2::element_line(color = "#f4f4f5"),
          axis.text          = ggplot2::element_text(color = "#71717a", size = 9),
          axis.title         = ggplot2::element_blank(),
          legend.title       = ggplot2::element_blank(),
          legend.position    = if (has_series) "top" else "none"
        )

      y_lo <- y_min_val()
      y_hi <- y_max_val()
      if (!is.null(y_lo) || !is.null(y_hi)) {
        p <- p + ggplot2::coord_cartesian(
          ylim = c(
            if (is.null(y_lo)) NA_real_ else y_lo,
            if (is.null(y_hi)) NA_real_ else y_hi
          )
        )
      }

      key_str <- paste(as.character(unlist(current_key())), collapse = "_")

      plotly::ggplotly(p) |>
        plotly::layout(
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor  = "rgba(0,0,0,0)"
        ) |>
        plotly::config(
          displayModeBar = TRUE,
          modeBarButtonsToRemove = list("select2d", "lasso2d"),
          toImageButtonOptions = list(
            format   = "png",
            filename = key_str
          )
        )
    })
  }

  invisible(shiny::runApp(shiny::shinyApp(ui, server)))
}
