#' Interactive explorer for the Greenland Statbank
#'
#' Launches a Shiny app for working with the Greenland Statbank
#' (bank.stat.gl). The app guides the user through three steps: find a
#' table (browse the subject areas or search the titles), choose values
#' for each variable, and fetch the data. The result is shown as a
#' table and a plot, and the app always shows the [daos::statbank_get()] call
#' that reproduces the selection, so a click-built query can be pasted
#' straight into a script.
#'
#' Time variables are selected with from/to dropdowns. Other variables
#' open a popup with a searchable checkbox list, select/deselect-all
#' shortcuts, and a running count; an empty selection means all values.
#' The settings panel under step 3 toggles the [daos::statbank_get()]
#' options: codes as column names, codes in the cells, and automatic
#' type conversion.
#'
#' Fetched data can be downloaded as a formatted Excel file (via
#' [daos::write_excel()] when `openxlsx2` is installed, otherwise CSV),
#' and the R code can be copied with one click. Pressing `Q` closes the
#' app and returns the last fetched dataset, so
#' `df <- statbank_app()` also works as a data-fetching workflow.
#'
#' The table list is fetched when the app starts (one request per
#' folder in the tree) and reused for the rest of the R session.
#'
#' @param lang Language of titles and labels: `"da"` (default), `"en"`,
#'   or `"kl"`.
#'
#' @return The last fetched dataset, invisibly (`NULL` if nothing was
#'   fetched).
#'
#' @examples
#' \dontrun{
#' statbank_app()
#' }
#'
#' @seealso [daos::statbank_get()], [daos::statbank_search()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang .data
#' @export
statbank_app <- function(lang = "da") {
  for (pkg in c("curl", "jsonlite", "shiny", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required for the app. Install with {.code install.packages('{pkg}')}.")
  }

  theme <- if (requireNamespace("bslib", quietly = TRUE)) {
    tryCatch(bslib::bs_theme(version = 5, bootswatch = "zephyr"),
             error = function(e) NULL)
  }

  css <- "
    body {
      background-color: #f1f5f9;
      font-family: -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      color: #1e293b;
    }
    .sb-hero {
      margin: -15px -15px 22px -15px;
      padding: 30px 34px 26px;
      background: linear-gradient(135deg, #0c3a63 0%, #1d62a8 100%);
      color: #fff;
    }
    .sb-hero h2 { font-weight: 700; letter-spacing: -0.3px; margin: 0 0 4px; color: #fff; }
    .sb-sub { color: #c7dbef; margin: 0; font-size: 15px; }
    .sb-tag {
      float: right; background: rgba(255, 255, 255, .14); color: #e6eef7;
      border-radius: 999px; padding: 4px 14px; font-size: 12.5px;
      margin-top: 6px; letter-spacing: .4px;
    }
    .well, .sb-card {
      background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
      box-shadow: 0 1px 2px rgba(15, 23, 42, .05), 0 4px 16px rgba(15, 23, 42, .05);
      padding: 24px;
    }
    .form-control, .selectize-input, .form-select {
      border-radius: 8px !important; border-color: #d6dee8 !important;
    }
    label { font-weight: 600; font-size: 13.5px; color: #334155; }
    .sb-step {
      margin: 22px 0 6px; font-size: 15px; font-weight: 700; color: #0f172a;
      display: flex; align-items: center;
    }
    .sb-step:first-child { margin-top: 0; }
    .sb-badge {
      display: inline-flex; width: 24px; height: 24px; border-radius: 50%;
      background: #1d62a8; color: #fff; align-items: center;
      justify-content: center; font-size: 13px; font-weight: 700;
      margin-right: 9px; flex: none;
    }
    .help-block, .sb-hint { color: #64748b; font-size: 12.5px; }
    .sb-count { color: #64748b; font-size: 12.5px; margin-top: -8px; margin-bottom: 12px; }
    #fetch {
      width: 100%; border-radius: 10px; font-weight: 600; padding: 10px;
      background: #1d62a8; border-color: #1d62a8; font-size: 15px;
      box-shadow: 0 2px 8px rgba(29, 98, 168, .35);
    }
    #fetch:hover { background: #174e86; border-color: #174e86; }
    .sb-pick {
      display: block; width: 100%; text-align: left; background: #fff;
      border: 1px solid #d6dee8; border-radius: 10px; padding: 8px 14px;
      margin-bottom: 10px; color: #1e293b; font-weight: 500;
      transition: border-color .12s, box-shadow .12s;
    }
    .sb-pick:hover {
      border-color: #1d62a8; box-shadow: 0 0 0 3px rgba(29, 98, 168, .12);
    }
    .sb-pick .sb-picksum {
      color: #64748b; font-size: 12px; float: right; font-weight: 400;
      background: #f1f5f9; border-radius: 999px; padding: 1px 10px;
    }
    .sb-modal-checks {
      max-height: 45vh; overflow-y: auto; border: 1px solid #e2e8f0;
      border-radius: 10px; padding: 12px 16px; margin-top: 10px; background: #fafcfe;
    }
    .sb-modal-checks .shiny-options-group { column-count: 2; column-gap: 28px; }
    .sb-modal-checks .checkbox { break-inside: avoid; margin: 3px 0; }
    .sb-advanced { margin-bottom: 12px; }
    .sb-advanced summary {
      cursor: pointer; color: #475569; font-size: 13px; font-weight: 600;
      margin-bottom: 6px;
    }
    .sb-advanced .checkbox { margin: 4px 0; }
    .sb-advanced .checkbox label { font-weight: 400; font-size: 13px; }
    .modal-content { border-radius: 14px; border: none; }
    .sb-welcome { max-width: 660px; }
    .sb-welcome h4 { font-weight: 700; margin-bottom: 16px; }
    .sb-welcome li { margin-bottom: 12px; line-height: 1.55; }
    .nav-pills { margin-bottom: 16px; gap: 6px; }
    .nav-pills .nav-link, .nav-pills > li > a { border-radius: 999px; font-weight: 500; }
    .nav-pills .nav-link.active, .nav-pills > li.active > a {
      background-color: #1d62a8 !important; color: #fff !important;
    }
    table.table {
      background: #fff; font-size: 13.5px; border-radius: 10px; overflow: hidden;
    }
    table.table thead th, table.table th {
      background: #f8fafc; color: #334155; border-bottom: 2px solid #e2e8f0;
    }
    .btn-default, .btn-secondary {
      border-radius: 8px; border-color: #d6dee8; background: #fff; color: #334155;
    }
    pre {
      background: #0f172a; color: #e2e8f0; border-radius: 10px; padding: 18px;
      font-size: 13px; border: none;
    }
  "

  # Q closes the app (ignored while typing in a field), like in
  # screen_timeseries(). The copy helper falls back to execCommand,
  # since navigator.clipboard is unavailable in embedded browsers such
  # as the RStudio viewer.
  app_js <- "
    document.addEventListener('keydown', function(e) {
      var t = (e.target.tagName || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (e.key === 'q' || e.key === 'Q') {
        Shiny.setInputValue('quit', Date.now());
      }
    });
    function sbFallbackCopy(txt) {
      var ta = document.createElement('textarea');
      ta.value = txt;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.focus();
      ta.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
    }
    function sbCopyCode(btn) {
      var txt = document.getElementById('code').innerText;
      var done = function() {
        btn.innerText = 'Kopieret!';
        setTimeout(function() { btn.innerText = 'Kopier kode'; }, 1500);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(done, function() {
          sbFallbackCopy(txt);
          done();
        });
      } else {
        sbFallbackCopy(txt);
        done();
      }
    }
  "

  ui <- shiny::fluidPage(
    theme = theme,
    shiny::tags$head(
      shiny::tags$style(shiny::HTML(css)),
      shiny::tags$script(shiny::HTML(app_js))
    ),
    shiny::div(
      class = "sb-hero",
      shiny::span(class = "sb-tag", "daos"),
      shiny::h2("Gr\u00f8nlands Statistikbank"),
      shiny::p(class = "sb-sub",
               "Find en tabel, v\u00e6lg dine data, og tag R-koden med hjem.")
    ),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 4,
        shiny::div(class = "sb-step",
                   shiny::span(class = "sb-badge", "1"), "Find en tabel"),
        shiny::helpText("Brug emnerne til at browse, eller s\u00f8g direkte i alle tabeltitler."),
        shiny::selectInput("subject", "Emne", choices = c("Alle emner" = "")),
        shiny::uiOutput("subnode_ui"),
        shiny::textInput("search", "Friteksts\u00f8gning",
                         placeholder = "fx befolkning, ledighed, fangst"),
        shiny::selectizeInput("table", "Tabel", choices = NULL,
                              options = list(placeholder = "V\u00e6lg en tabel fra listen")),
        shiny::div(class = "sb-count", shiny::textOutput("n_tables", inline = TRUE)),
        shiny::uiOutput("varpickers"),
        shiny::uiOutput("fetch_area"),
        shiny::helpText(style = "margin-top: 16px;",
                        "Genvej: tryk Q for at lukke appen. Det seneste udtr\u00e6k returneres til R.")
      ),
      shiny::mainPanel(
        width = 8,
        shiny::uiOutput("main_area")
      )
    )
  )

  has_openxlsx   <- requireNamespace("openxlsx2", quietly = TRUE)
  download_label <- if (has_openxlsx) "Download Excel" else "Download CSV"

  server <- function(input, output, session) {
    tables <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$quit, {
      shiny::stopApp(invisible(fetched()))
    })

    # Fetch the subject areas and the table list once at startup (the
    # table list is cached for the session).
    shiny::observe({
      shiny::withProgress(message = "Henter tabelliste fra bank.stat.gl ...", {
        subjects <- statbank_nodes("", lang = lang)
        shiny::updateSelectInput(
          session, "subject",
          choices = c("Alle emner" = "", stats::setNames(subjects$id, subjects$text))
        )
        tables(statbank_tables(lang = lang))
      })
    })

    # Sub-folder picker for the chosen subject, so the tree can be
    # browsed without knowing what to search for.
    output$subnode_ui <- shiny::renderUI({
      shiny::req(shiny::isTruthy(input$subject))
      nodes <- statbank_nodes(input$subject, lang = lang)
      folders <- nodes[nodes$type == "l", ]
      if (nrow(folders) == 0) return(NULL)
      shiny::selectInput(
        "subnode", "Undergruppe",
        choices = c("Alle undergrupper" = "", stats::setNames(folders$id, folders$text))
      )
    })

    # Subject, sub-folder, and search all narrow the table picker.
    filtered_tables <- shiny::reactive({
      tbl <- shiny::req(tables())
      prefix <- if (shiny::isTruthy(input$subject)) input$subject else ""
      if (nzchar(prefix) && shiny::isTruthy(input$subnode)) {
        prefix <- paste(prefix, input$subnode, sep = "/")
      }
      if (nzchar(prefix)) {
        keep <- tbl$path == prefix | startsWith(tbl$path, paste0(prefix, "/"))
        tbl <- tbl[keep, ]
      }
      if (shiny::isTruthy(input$search)) {
        hit <- grepl(input$search, paste(tbl$title, tbl$id), ignore.case = TRUE)
        tbl <- tbl[hit, ]
      }
      tbl
    })

    shiny::observe({
      tbl <- filtered_tables()
      choices <- stats::setNames(paste(tbl$path, tbl$id, sep = "/"), tbl$title)
      shiny::updateSelectizeInput(session, "table",
                                  choices = choices, selected = character(0),
                                  server = TRUE)
    })

    output$n_tables <- shiny::renderText({
      n <- nrow(filtered_tables())
      paste(n, if (n == 1) "tabel matcher" else "tabeller matcher")
    })

    meta <- shiny::reactive({
      shiny::req(input$table)
      statbank_meta(input$table, lang = lang)
    })

    is_time_var <- function(vars, j) {
      vars$time[j] ||
        tolower(vars$code[j]) == "time" ||
        tolower(vars$text[j]) == "tid"
    }

    # Selected value codes per variable code. Defaults: first value for
    # ordinary variables (often the total); time is handled by the
    # from/to pickers.
    sel_store <- shiny::reactiveVal(list())
    shiny::observeEvent(meta(), {
      vars <- meta()$variables
      init <- lapply(seq_len(nrow(vars)), function(j) {
        if (is_time_var(vars, j)) NULL else vars$values[[j]][1]
      })
      names(init) <- vars$code
      sel_store(init)
    })

    # Step 2: from/to dropdowns for time, and one popup button per
    # other variable showing a selection summary.
    output$varpickers <- shiny::renderUI({
      vars <- shiny::req(meta())$variables
      sel  <- sel_store()
      pickers <- lapply(seq_len(nrow(vars)), function(j) {
        values <- stats::setNames(vars$values[[j]], vars$valueTexts[[j]])
        if (is_time_var(vars, j)) {
          shiny::tagList(
            shiny::tags$label(paste0(vars$text[j], " (periode)")),
            shiny::fluidRow(
              shiny::column(6, shiny::selectInput(
                paste0("sbfrom_", j), "Fra",
                choices = values, selected = values[[1]]
              )),
              shiny::column(6, shiny::selectInput(
                paste0("sbto_", j), "Til",
                choices = values, selected = values[[length(values)]]
              ))
            )
          )
        } else {
          cur <- sel[[vars$code[j]]]
          n   <- length(values)
          summary <- if (is.null(cur) || length(cur) == 0 || length(cur) == n) {
            "alle valgt"
          } else {
            paste0(length(cur), " af ", n, " valgt")
          }
          shiny::actionButton(
            paste0("sbopen_", j),
            class = "sb-pick btn",
            label = shiny::tagList(vars$text[j],
                                   shiny::span(class = "sb-picksum", summary))
          )
        }
      })
      shiny::tagList(
        shiny::div(class = "sb-step",
                   shiny::span(class = "sb-badge", "2"), "V\u00e6lg dine data"),
        shiny::helpText("S\u00e6t perioden med fra/til, og klik p\u00e5 de andre variabler for at v\u00e6lge v\u00e6rdier i en liste."),
        pickers
      )
    })

    # The popup: a searchable checkbox list for one variable. The
    # working selection lives in its own reactiveVal while the popup is
    # open, and is written to sel_store on OK.
    modal_var <- shiny::reactiveVal(NULL)
    working   <- shiny::reactiveVal(character())

    open_observers <- list()
    shiny::observeEvent(meta(), {
      lapply(open_observers, function(o) o$destroy())
      vars <- meta()$variables
      obs <- lapply(seq_len(nrow(vars)), function(j) {
        if (is_time_var(vars, j)) return(NULL)
        shiny::observeEvent(input[[paste0("sbopen_", j)]], {
          modal_var(j)
          cur <- sel_store()[[vars$code[j]]]
          working(if (is.null(cur)) character() else cur)
          shiny::showModal(shiny::modalDialog(
            title = vars$text[j],
            shiny::textInput("modal_filter", NULL,
                             placeholder = "Filtrer i listen ..."),
            shiny::div(
              shiny::actionLink("modal_all", "V\u00e6lg alle viste"),
              " | ",
              shiny::actionLink("modal_none", "Frav\u00e6lg alle viste"),
              shiny::span(class = "sb-hint", style = "float: right;",
                          shiny::textOutput("modal_count", inline = TRUE))
            ),
            shiny::div(class = "sb-modal-checks", shiny::uiOutput("modal_body")),
            shiny::helpText("V\u00e6lges intet, bruges alle v\u00e6rdier."),
            footer = shiny::tagList(
              shiny::modalButton("Annuller"),
              shiny::actionButton("modal_ok", "OK", class = "btn-primary")
            ),
            size = "l", easyClose = TRUE
          ))
        }, ignoreInit = TRUE)
      })
      open_observers <<- Filter(Negate(is.null), obs)
    })

    # Values visible in the popup given the filter text.
    modal_visible <- shiny::reactive({
      j    <- shiny::req(modal_var())
      vars <- meta()$variables
      codes <- vars$values[[j]]
      texts <- vars$valueTexts[[j]]
      if (shiny::isTruthy(input$modal_filter)) {
        keep  <- grepl(input$modal_filter, texts, ignore.case = TRUE) |
          grepl(input$modal_filter, codes, ignore.case = TRUE)
        codes <- codes[keep]
        texts <- texts[keep]
      }
      stats::setNames(codes, texts)
    })

    shiny::observeEvent(input$modal_filter, {
      shiny::freezeReactiveValue(input, "modal_check")
    })

    output$modal_body <- shiny::renderUI({
      v <- modal_visible()
      if (length(v) == 0) return(shiny::p(class = "sb-hint", "Ingen v\u00e6rdier matcher filteret."))
      shiny::checkboxGroupInput("modal_check", NULL, choices = v,
                                selected = intersect(shiny::isolate(working()), v))
    })

    # Checkbox changes only affect the visible values, so a filtered
    # view never silently drops hidden selections.
    shiny::observeEvent(input$modal_check, {
      v <- shiny::isolate(modal_visible())
      working(union(setdiff(working(), v), intersect(input$modal_check, v)))
    }, ignoreNULL = FALSE, ignoreInit = TRUE)

    shiny::observeEvent(input$modal_all, {
      shiny::updateCheckboxGroupInput(session, "modal_check",
                                      selected = unname(modal_visible()))
    })
    shiny::observeEvent(input$modal_none, {
      shiny::updateCheckboxGroupInput(session, "modal_check",
                                      selected = character(0))
    })

    output$modal_count <- shiny::renderText({
      paste(length(working()), "valgt")
    })

    shiny::observeEvent(input$modal_ok, {
      j    <- shiny::req(modal_var())
      vars <- meta()$variables
      s <- sel_store()
      s[[vars$code[j]]] <- working()
      sel_store(s)
      modal_var(NULL)
      shiny::removeModal()
    })

    output$fetch_area <- shiny::renderUI({
      shiny::req(meta())
      shiny::tagList(
        shiny::div(class = "sb-step",
                   shiny::span(class = "sb-badge", "3"), "Hent"),
        shiny::tags$details(
          class = "sb-advanced",
          shiny::tags$summary("Indstillinger"),
          shiny::checkboxInput("opt_codecols", "Koder som kolonnenavne", FALSE),
          shiny::checkboxInput("opt_codevals", "Koder i cellerne i stedet for tekster", FALSE),
          shiny::checkboxInput("opt_typeconvert", "Konverter kolonnetyper automatisk", TRUE)
        ),
        shiny::actionButton("fetch", "Hent data", class = "btn-primary")
      )
    })

    # Option getters with defaults, since the inputs live in a renderUI
    # and may not exist yet.
    opt_col_names <- function() if (isTRUE(input$opt_codecols)) "code" else "text"
    opt_values    <- function() if (isTRUE(input$opt_codevals)) "code" else "text"
    opt_typeconv  <- function() !isFALSE(input$opt_typeconvert)

    # Selections as a named list, variable code -> value codes. Time
    # variables come from the from/to pickers; an empty or complete
    # selection means all values.
    selections <- shiny::reactive({
      vars <- shiny::req(meta())$variables
      sel  <- sel_store()
      sels <- lapply(seq_len(nrow(vars)), function(j) {
        values <- vars$values[[j]]
        if (is_time_var(vars, j)) {
          i1 <- match(input[[paste0("sbfrom_", j)]], values)
          i2 <- match(input[[paste0("sbto_", j)]], values)
          if (is.na(i1) || is.na(i2)) return("*")
          rng <- sort(c(i1, i2))
          if (rng[1] == 1 && rng[2] == length(values)) return("*")
          return(values[rng[1]:rng[2]])
        }
        cur <- sel[[vars$code[j]]]
        if (is.null(cur) || length(cur) == 0 || length(cur) == length(values)) "*" else cur
      })
      stats::setNames(sels, vars$code)
    })

    # Fetched data lives in a reactiveVal so the main panel can tell
    # "not fetched yet" apart from "fetching failed". Switching table
    # clears it.
    fetched <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$table, fetched(NULL))
    shiny::observeEvent(input$fetch, {
      shiny::withProgress(message = "Henter data ...", {
        fetched(do.call(statbank_get, c(
          list(meta()$path),
          selections(),
          list(lang = lang,
               .col_names = opt_col_names(),
               .values = opt_values(),
               .type_convert = opt_typeconv())
        )))
      })
    })

    # The main panel walks through three states: a welcome guide, a
    # prompt to pick values, and the results.
    output$main_area <- shiny::renderUI({
      if (!shiny::isTruthy(input$table)) {
        return(shiny::div(
          class = "sb-card sb-welcome",
          shiny::h4("S\u00e5dan bruger du appen"),
          shiny::tags$ol(
            shiny::tags$li(shiny::strong("Find en tabel."),
                           " V\u00e6lg et emne i venstre side, eller skriv i s\u00f8gefeltet.",
                           " Listen under \"Tabel\" viser de tabeller, der matcher."),
            shiny::tags$li(shiny::strong("V\u00e6lg dine data."),
                           " S\u00e6t perioden med fra/til, og klik p\u00e5 hver af de andre",
                           " variabler for at v\u00e6lge v\u00e6rdier i en liste.",
                           " V\u00e6lges intet, bruges alle v\u00e6rdier."),
            shiny::tags$li(shiny::strong("Hent."),
                           " Tryk p\u00e5 \"Hent data\" og se resultatet som tabel og graf.",
                           " Fanen \"R-kode\" viser den kode, der genskaber udtr\u00e6kket",
                           " i et R-script.")
          ),
          shiny::p(class = "sb-hint",
                   "Data hentes direkte fra Gr\u00f8nlands Statistiks statistikbank (bank.stat.gl).",
                   " Tryk Q for at lukke appen og f\u00e5 det seneste udtr\u00e6k med tilbage til R.")
        ))
      }
      shiny::tagList(
        shiny::h4(meta()$title),
        if (is.null(fetched())) {
          shiny::div(class = "sb-card",
                     shiny::p("V\u00e6lg v\u00e6rdier i venstre side, og tryk p\u00e5 ",
                              shiny::strong("Hent data"), "."))
        } else {
          shiny::tabsetPanel(
            type = "pills",
            shiny::tabPanel("Data",
                            shiny::div(style = "margin: 10px 0;",
                                       shiny::downloadButton("download", download_label,
                                                             class = "btn-sm")),
                            shiny::div(class = "sb-hint", shiny::textOutput("n_rows")),
                            shiny::tableOutput("preview")),
            shiny::tabPanel("Graf", shiny::plotOutput("plot", height = "500px")),
            shiny::tabPanel("R-kode",
                            shiny::p(class = "sb-hint",
                                     "Kopier koden ind i dit script for at gentage udtr\u00e6kket uden appen:"),
                            shiny::tags$button(
                              class = "btn btn-default btn-sm",
                              style = "margin-bottom: 8px;",
                              onclick = "sbCopyCode(this);",
                              "Kopier kode"
                            ),
                            shiny::verbatimTextOutput("code"))
          )
        }
      )
    })

    output$n_rows <- shiny::renderText({
      d <- shiny::req(fetched())
      if (nrow(d) > 100) paste0("Viser de f\u00f8rste 100 af ", nrow(d), " r\u00e6kker.")
      else paste(nrow(d), "r\u00e6kker.")
    })

    output$preview <- shiny::renderTable({
      d <- utils::head(shiny::req(fetched()), 100)
      d[] <- lapply(d, function(x) {
        if (is.numeric(x)) {
          format(x, trim = TRUE, scientific = FALSE, drop0trailing = TRUE)
        } else {
          x
        }
      })
      d
    })

    # Excel via write_excel() when openxlsx2 is installed (frozen
    # header, thousand separators), otherwise semicolon CSV.
    output$download <- shiny::downloadHandler(
      filename = function() {
        id <- sub("\\.px$", "", basename(meta()$path), ignore.case = TRUE)
        paste0(id, "_", nowf(), if (has_openxlsx) ".xlsx" else ".csv")
      },
      content = function(file) {
        d <- shiny::req(fetched())
        if (has_openxlsx) {
          tmp <- tempfile(fileext = ".xlsx")
          write_excel(d, tmp)
          file.copy(tmp, file, overwrite = TRUE)
          unlink(tmp)
        } else {
          readr::write_csv2(d, file)
        }
      }
    )

    output$plot <- shiny::renderPlot({
      d    <- shiny::req(fetched())
      vars <- meta()$variables
      time_idx <- which(vars$time | tolower(vars$code) == "time" | tolower(vars$text) == "tid")
      shiny::validate(shiny::need(length(time_idx) > 0, "Tabellen har ingen tidsvariabel at plotte over."))
      time_col <- if (isTRUE(input$opt_codecols)) {
        vars$code[time_idx[1]]
      } else {
        tolower(vars$text[time_idx[1]])
      }
      shiny::validate(shiny::need(time_col %in% names(d), "Tidsvariablen indgaar ikke i udtraekket."))

      other <- setdiff(names(d), c(time_col, "value"))
      d$grp <- if (length(other) > 0) interaction(d[other], sep = ", ") else factor("serie")
      d$tid_num <- suppressWarnings(as.numeric(d[[time_col]]))
      x_col <- if (all(!is.na(d$tid_num))) "tid_num" else time_col

      ggplot2::ggplot(d, ggplot2::aes(x = .data[[x_col]], y = .data$value,
                                      colour = .data$grp, group = .data$grp)) +
        ggplot2::geom_line(linewidth = 0.8) +
        ggplot2::labs(x = vars$text[time_idx[1]], y = "value", colour = NULL) +
        ggplot2::theme_minimal(base_size = 13)
    })

    # The statbank_get() call that reproduces the selection, one call per line.
    output$code <- shiny::renderText({
      shiny::req(meta())
      vars <- meta()$variables
      sels <- selections()
      args <- vapply(seq_along(sels), function(j) {
        if (identical(sels[[j]], "*")) return(NA_character_)
        nm <- tolower(vars$text[j])
        if (!grepl("^[a-z][a-z0-9._]*$", nm)) nm <- paste0("`", nm, "`")
        vals <- paste0('"', sels[[j]], '"', collapse = ", ")
        if (length(sels[[j]]) > 1) vals <- paste0("c(", vals, ")")
        paste0("  ", nm, " = ", vals)
      }, character(1))
      args <- args[!is.na(args)]
      opts <- c(
        if (lang != "da") paste0('  lang = "', lang, '"'),
        if (isTRUE(input$opt_codecols)) '  .col_names = "code"',
        if (isTRUE(input$opt_codevals)) '  .values = "code"',
        if (isFALSE(input$opt_typeconvert)) '  .type_convert = FALSE'
      )
      paste0(
        "df <- statbank_get(\n",
        paste(c(paste0('  "', meta()$path, '"'), args, opts), collapse = ",\n"),
        "\n)"
      )
    })
  }

  invisible(shiny::runApp(shiny::shinyApp(ui, server), quiet = TRUE))
}
