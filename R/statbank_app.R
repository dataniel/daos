#' Interactive explorer for the Greenland Statbank
#'
#' Launches a Shiny app for working with the Greenland Statbank
#' (bank.stat.gl). The app guides the user through three steps: find a
#' table (search the titles, or walk the subject tree in a two-column
#' browser that also responds to `h`/`j`/`k`/`l` and the arrow keys),
#' choose values for each variable, and fetch the data. The
#' result is shown as a table and a plot, and the app always shows the
#' [daos::statbank_get()] call that reproduces the selection, so a
#' click-built query can be pasted straight into a script.
#'
#' Time variables, and numeric variables with many values (such as
#' age), are selected with from/to dropdowns. Other variables open a
#' popup with a searchable checkbox list, select/deselect-all
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
      margin: 24px 0 8px; padding-top: 18px; border-top: 1px solid #eef2f7;
      font-size: 15px; font-weight: 700; color: #0f172a;
      display: flex; align-items: center;
    }
    .sb-step:first-child { margin-top: 0; padding-top: 0; border-top: none; }
    .well .form-group { margin-bottom: 16px; }
    .well .help-block { display: block; margin: 2px 0 14px; }
    .sb-fromto { margin-bottom: 6px; }
    .sb-fromto label { font-size: 12px; color: #64748b; margin-bottom: 2px; }
    .sb-fromto .form-group { margin-bottom: 8px; }
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
    .sb-modal-checks .checkbox { margin: 0; }
    .sb-modal-checks .checkbox label {
      display: block; width: 100%; padding: 5px 8px; border-radius: 6px;
      font-weight: 400;
    }
    .sb-modal-checks .checkbox label:hover { background: #e8f0fa; }
    .sb-advanced { margin-bottom: 12px; }
    .sb-advanced summary {
      cursor: pointer; color: #475569; font-size: 13px; font-weight: 600;
      margin-bottom: 6px;
    }
    .sb-advanced .checkbox { margin: 4px 0; }
    .sb-advanced .checkbox label { font-weight: 400; font-size: 13px; }
    .modal-content { border-radius: 14px; border: none; }
    .sb-welcome { max-width: 660px; }
    .sb-welcome li { margin-bottom: 12px; line-height: 1.55; }
    .sb-crumbs { font-size: 13.5px; color: #475569; margin: 10px 0 12px; }
    .sb-crumbs a { cursor: pointer; color: #1d62a8; text-decoration: none; font-weight: 600; }
    .sb-crumbs a:hover { text-decoration: underline; }
    .sb-crumbs .sb-sep { color: #94a3b8; margin: 0 6px; }
    .sb-browser { display: flex; gap: 14px; }
    .sb-col {
      flex: 1; min-width: 0; max-height: 58vh; overflow-y: auto;
      border: 1px solid #e2e8f0; border-radius: 10px; background: #fafcfe;
      padding: 6px;
    }
    .sb-colhead {
      font-size: 11.5px; font-weight: 700; letter-spacing: .5px;
      text-transform: uppercase; color: #94a3b8; padding: 6px 10px 4px;
    }
    .sb-item {
      display: block; padding: 7px 10px; border-radius: 8px; cursor: pointer;
      font-size: 13.5px; color: #1e293b; line-height: 1.35;
    }
    .sb-item:hover { background: #e8f0fa; }
    .sb-item.cursor {
      outline: 2px solid #1d62a8; outline-offset: -2px; background: #e8f0fa;
    }
    .sb-item.active { background: #1d62a8; color: #fff; }
    .sb-item.active .sb-itemmark { color: #c7dbef; }
    .sb-itemmark { color: #94a3b8; float: right; margin-left: 8px; }
    .sb-item.sb-tbl { color: #0f3b66; font-weight: 500; }
    .sb-item.sb-tbl:hover { background: #e3eefc; }
    .sb-tblicon { color: #1d62a8; margin-right: 8px; }
    .sb-guide summary {
      cursor: pointer; color: #475569; font-size: 13.5px; font-weight: 600;
      margin-top: 16px;
    }
    .sb-back {
      display: inline-block; margin-bottom: 12px; font-weight: 600;
      color: #1d62a8; text-decoration: none;
    }
    .sb-back:hover { text-decoration: underline; color: #174e86; }
    .sb-tablesub { color: #64748b; font-size: 13px; margin: -4px 0 14px; }
    .sb-notes { margin: 10px 0; }
    .sb-notes summary {
      cursor: pointer; color: #475569; font-size: 13px; font-weight: 600;
    }
    .sb-notes p {
      color: #475569; font-size: 12.5px; margin: 8px 0 4px; line-height: 1.5;
    }
    .sb-varinfo { margin-top: 4px; }
    .sb-varinfo td, .sb-varinfo th { font-size: 13px; padding: 8px 10px; }
    .sb-varinfo .sb-hintcell { color: #64748b; }
    .sb-guide ol { margin-top: 10px; }
    .sb-guide li { margin-bottom: 8px; }
    .nav-pills { margin-bottom: 16px; gap: 8px; }
    .nav-pills .nav-link, .nav-pills > li > a {
      border-radius: 999px; font-weight: 600; cursor: pointer;
      background: #fff; border: 1px solid #d6dee8; color: #334155;
      padding: 7px 18px; box-shadow: 0 1px 2px rgba(15, 23, 42, .05);
      transition: border-color .12s, color .12s, box-shadow .12s;
    }
    .nav-pills .nav-link:hover, .nav-pills > li > a:hover {
      border-color: #1d62a8; color: #1d62a8;
      box-shadow: 0 0 0 3px rgba(29, 98, 168, .12);
    }
    .nav-pills .nav-link.active, .nav-pills > li.active > a {
      background-color: #1d62a8 !important; color: #fff !important;
      border-color: #1d62a8 !important;
    }
    .sb-tabicon { margin-right: 7px; opacity: .75; }
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
  # screen_timeseries(). The tree browser is navigated with h/j/k/l or
  # the arrow keys: a cursor moves over the current column, l/Enter
  # clicks the row, and h clicks the next-to-last breadcrumb (one level
  # up). The copy helper falls back to execCommand, since
  # navigator.clipboard is unavailable in embedded browsers such as the
  # RStudio viewer.
  app_js <- "
    document.addEventListener('keydown', function(e) {
      var t = (e.target.tagName || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (e.key === 'q' || e.key === 'Q') {
        Shiny.setInputValue('quit', Date.now());
        return;
      }
      // Enter on a focused button/link keeps its default behaviour.
      if (e.key === 'Enter' && (t === 'button' || t === 'a')) return;

      if (document.querySelector('.modal-backdrop')) return;

      var key  = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      var down = (key === 'j' || key === 'ArrowDown');
      var up   = (key === 'k' || key === 'ArrowUp');
      var open = (key === 'l' || key === 'ArrowRight' || key === 'Enter');
      var back = (key === 'h' || key === 'ArrowLeft');
      if (!(down || up || open || back)) return;

      var items = document.querySelectorAll('.sb-browser .sb-col:last-child .sb-item');
      if (items.length === 0) {
        // A table is chosen: h/left goes back to the folder it sits in.
        var b = document.getElementById('back_to_browse');
        if (back && b) {
          e.preventDefault();
          b.click();
        }
        return;
      }
      e.preventDefault();

      var cur = -1;
      for (var i = 0; i < items.length; i++) {
        if (items[i].classList.contains('cursor')) { cur = i; break; }
      }

      if (down || up) {
        var nxt;
        if (cur === -1) {
          nxt = down ? 0 : items.length - 1;
        } else {
          nxt = down ? Math.min(cur + 1, items.length - 1) : Math.max(cur - 1, 0);
          items[cur].classList.remove('cursor');
        }
        items[nxt].classList.add('cursor');
        items[nxt].scrollIntoView({block: 'nearest'});
      } else if (open) {
        if (cur >= 0) items[cur].click();
      } else if (back) {
        var crumbs = document.querySelectorAll('.sb-crumbs a');
        if (crumbs.length >= 2) crumbs[crumbs.length - 2].click();
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
        shiny::textInput("search", "Friteksts\u00f8gning",
                         placeholder = "fx befolkning, ledighed, fangst"),
        shiny::selectizeInput("table", "Tabel", choices = NULL,
                              options = list(placeholder = "V\u00e6lg en tabel fra listen")),
        shiny::div(class = "sb-count", shiny::textOutput("n_tables", inline = TRUE)),
        shiny::helpText("Du kan ogs\u00e5 klikke dig gennem emnerne i oversigten til h\u00f8jre."),
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

    # Fetch the table list once at startup (cached for the session).
    shiny::observe({
      shiny::withProgress(message = "Henter tabelliste fra bank.stat.gl ...", {
        tables(statbank_tables(lang = lang))
      })
    })

    # Node listings for the tree browser, cached per folder.
    node_cache <- new.env(parent = emptyenv())
    get_nodes <- function(path) {
      key <- if (nzchar(path)) path else "."
      if (is.null(node_cache[[key]])) {
        node_cache[[key]] <- statbank_nodes(path, lang = lang)
      }
      node_cache[[key]]
    }

    # The search narrows the table picker.
    filtered_tables <- shiny::reactive({
      tbl <- shiny::req(tables())
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

    # The chosen table and the browser position. A table can be chosen
    # from the search picker or by clicking in the tree browser.
    current_table <- shiny::reactiveVal(NULL)
    cur_path      <- shiny::reactiveVal("")

    shiny::observeEvent(input$table, {
      shiny::req(shiny::isTruthy(input$table))
      current_table(input$table)
      cur_path(sub("/[^/]+$", "", input$table))
    })

    shiny::observeEvent(input$pick_table, {
      current_table(input$pick_table)
      shiny::updateSelectizeInput(session, "table", selected = input$pick_table)
    })

    shiny::observeEvent(input$browse_to, {
      cur_path(input$browse_to)
    })

    shiny::observeEvent(input$back_to_browse, {
      current_table(NULL)
      shiny::updateSelectizeInput(session, "table", selected = character(0))
    })

    meta <- shiny::reactive({
      shiny::req(current_table())
      statbank_meta(current_table(), lang = lang)
    })

    # Notes, source, and contact come with the data response, not the
    # metadata, so a one-cell probe fetch supplies them for the
    # overview card.
    table_info <- shiny::reactive({
      m <- shiny::req(meta())
      sels <- lapply(m$variables$values, function(v) v[1])
      names(sels) <- m$variables$code
      tryCatch(
        do.call(statbank_get,
                c(list(m$path), sels, list(lang = lang, .type_convert = FALSE))),
        error = function(e) NULL
      )
    })

    is_time_var <- function(vars, j) {
      vars$time[j] ||
        tolower(vars$code[j]) == "time" ||
        tolower(vars$text[j]) == "tid"
    }

    # Variables that get from/to pickers instead of a checkbox popup:
    # time, plus numeric variables with many values (e.g. age), where a
    # list of a hundred checkboxes would be unwieldy.
    is_range_var <- function(vars, j) {
      if (is_time_var(vars, j)) return(TRUE)
      texts <- vars$valueTexts[[j]]
      length(texts) > 10 &&
        !anyNA(suppressWarnings(as.numeric(texts)))
    }

    # Selected value codes per variable code. Defaults: first value for
    # ordinary variables (often the total); time is handled by the
    # from/to pickers.
    sel_store <- shiny::reactiveVal(list())
    shiny::observeEvent(meta(), {
      vars <- meta()$variables
      init <- lapply(seq_len(nrow(vars)), function(j) {
        if (is_range_var(vars, j)) NULL else vars$values[[j]][1]
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
        if (is_range_var(vars, j)) {
          shiny::tagList(
            shiny::tags$label(paste0(vars$text[j],
                                     if (is_time_var(vars, j)) " (periode)" else " (interval)")),
            shiny::div(
              class = "sb-fromto",
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
        if (is_range_var(vars, j)) return(NULL)
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
        if (is_range_var(vars, j)) {
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
    shiny::observeEvent(current_table(), fetched(NULL), ignoreNULL = FALSE)
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

    # A clickable row in the tree browser. Folders navigate, tables are
    # picked; both go through Shiny.setInputValue, so no observers pile
    # up as the columns re-render. Folders show how many tables they
    # hold (from the cached table list), and the chevron only appears
    # when there are subfolders, so a leaf folder is recognisable.
    browse_item <- function(row, base_path, active = FALSE, cursor = FALSE, tbl = NULL) {
      full <- if (nzchar(base_path)) paste(base_path, row$id, sep = "/") else row$id
      if (row$type == "l") {
        mark <- "\u203a"
        if (!is.null(tbl)) {
          under   <- startsWith(tbl$path, paste0(full, "/"))
          n_tab   <- sum(tbl$path == full | under)
          has_sub <- any(under)
          mark <- paste0(n_tab, if (n_tab == 1) " tabel" else " tabeller",
                         if (has_sub) "  \u203a" else "")
        }
        shiny::div(
          class = paste(c("sb-item", if (active) "active", if (cursor) "cursor"),
                        collapse = " "),
          onclick = sprintf(
            "Shiny.setInputValue('browse_to', '%s', {priority: 'event'})", full),
          row$text,
          shiny::span(class = "sb-itemmark", mark)
        )
      } else {
        shiny::div(
          class = paste(c("sb-item sb-tbl", if (cursor) "cursor"), collapse = " "),
          onclick = sprintf(
            "Shiny.setInputValue('pick_table', '%s', {priority: 'event'})", full),
          shiny::span(class = "sb-tblicon", "\u25a6"),
          row$text
        )
      }
    }

    # The main panel walks through three states: the tree browser, a
    # prompt to pick values, and the results.
    output$main_area <- shiny::renderUI({
      if (is.null(current_table())) {
        path <- cur_path()
        segs <- if (nzchar(path)) strsplit(path, "/", fixed = TRUE)[[1]] else character()

        # Breadcrumb with clickable ancestors.
        crumbs <- list(shiny::tags$a(
          onclick = "Shiny.setInputValue('browse_to', '', {priority: 'event'})",
          "Statistikbanken"))
        for (i in seq_along(segs)) {
          parent <- paste(segs[seq_len(i - 1)], collapse = "/")
          nodes  <- get_nodes(parent)
          lbl    <- nodes$text[match(segs[i], nodes$id)]
          target <- paste(segs[seq_len(i)], collapse = "/")
          crumbs <- c(crumbs, list(
            shiny::span(class = "sb-sep", "/"),
            shiny::tags$a(onclick = sprintf(
              "Shiny.setInputValue('browse_to', '%s', {priority: 'event'})", target),
              if (is.na(lbl)) segs[i] else lbl)
          ))
        }

        tbl <- tables()
        cur_nodes <- get_nodes(path)
        cur_col <- shiny::div(
          class = "sb-col",
          shiny::div(class = "sb-colhead", "Indhold"),
          lapply(seq_len(nrow(cur_nodes)), function(i) {
            browse_item(cur_nodes[i, ], path, cursor = i == 1, tbl = tbl)
          })
        )

        columns <- if (nzchar(path)) {
          parent_path  <- if (grepl("/", path, fixed = TRUE)) sub("/[^/]+$", "", path) else ""
          parent_nodes <- get_nodes(parent_path)
          parent_col <- shiny::div(
            class = "sb-col",
            shiny::div(class = "sb-colhead", "Niveau op"),
            lapply(seq_len(nrow(parent_nodes)), function(i) {
              browse_item(parent_nodes[i, ], parent_path,
                          active = parent_nodes$id[i] == segs[length(segs)],
                          tbl = tbl)
            })
          )
          shiny::div(class = "sb-browser", parent_col, cur_col)
        } else {
          shiny::div(class = "sb-browser", cur_col)
        }

        return(shiny::div(
          class = "sb-card",
          shiny::h4("Gennemse statistikbanken"),
          shiny::p(class = "sb-hint",
                   "Klik dig ned gennem emnerne, og klik p\u00e5 en tabel for at v\u00e6lge den.",
                   " Du kan ogs\u00e5 bruge s\u00f8gefeltet til venstre.",
                   " Tastatur: j/k eller pil op/ned flytter mark\u00f8ren, l/Enter \u00e5bner,",
                   " h eller pil venstre g\u00e5r et niveau op, ogs\u00e5 fra en valgt tabel."),
          shiny::div(class = "sb-crumbs", crumbs),
          columns,
          shiny::tags$details(
            class = "sb-guide",
            shiny::tags$summary("S\u00e5dan bruger du appen"),
            shiny::tags$ol(
              shiny::tags$li(shiny::strong("Find en tabel."),
                             " Brug s\u00f8gefeltet til venstre, eller klik dig gennem",
                             " emnerne ovenfor. Klik p\u00e5 en tabel for at v\u00e6lge den."),
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
          )
        ))
      }
      tbl_info <- tables()
      sub_line <- NULL
      if (!is.null(tbl_info)) {
        row <- tbl_info[paste(tbl_info$path, tbl_info$id, sep = "/") == current_table(), ]
        if (nrow(row) > 0) {
          sub_line <- paste0(
            "Tabel ", row$id[1],
            if (!is.na(row$updated[1])) paste0(" \u00b7 senest opdateret ", substr(row$updated[1], 1, 10))
          )
        }
      }

      probe   <- table_info()
      src     <- attr(probe, "source")
      contact <- attr(probe, "contact")
      notes   <- attr(probe, "notes")
      src_line <- paste(c(
        if (!is.null(src)) paste("Kilde:", src),
        if (!is.null(contact)) paste("Kontakt:", paste(contact, collapse = "; "))
      ), collapse = " \u00b7 ")
      notes_block <- if (length(notes) > 0) {
        shiny::tags$details(
          class = "sb-notes",
          shiny::tags$summary(paste0("Noter (", length(notes), ")")),
          lapply(notes, function(n) shiny::p(n))
        )
      }

      shiny::tagList(
        shiny::actionLink("back_to_browse", "\u2190 Tilbage til oversigten",
                          class = "sb-back"),
        shiny::h4(meta()$title),
        if (!is.null(sub_line)) shiny::p(class = "sb-tablesub", sub_line),
        if (is.null(fetched())) {
          vars <- meta()$variables
          rows <- lapply(seq_len(nrow(vars)), function(j) {
            texts <- vars$valueTexts[[j]]
            ex <- paste(utils::head(texts, 3), collapse = ", ")
            if (length(texts) > 3) ex <- paste0(ex, ", ...")
            shiny::tags$tr(
              shiny::tags$td(vars$text[j]),
              shiny::tags$td(length(texts)),
              shiny::tags$td(class = "sb-hintcell", ex)
            )
          })
          shiny::div(
            class = "sb-card",
            shiny::p(shiny::strong("Tabellens variabler")),
            shiny::tags$table(
              class = "table sb-varinfo",
              shiny::tags$thead(shiny::tags$tr(
                shiny::tags$th("Variabel"),
                shiny::tags$th("Antal v\u00e6rdier"),
                shiny::tags$th("Eksempler p\u00e5 v\u00e6rdier")
              )),
              shiny::tags$tbody(rows)
            ),
            if (nzchar(src_line)) shiny::p(class = "sb-hint", src_line),
            notes_block,
            shiny::p(class = "sb-hint",
                     "V\u00e6lg v\u00e6rdier i venstre side, og tryk p\u00e5 ",
                     shiny::strong("Hent data"),
                     ". Et tomt valg betyder alle v\u00e6rdier.")
          )
        } else {
          shiny::tabsetPanel(
            type = "pills",
            shiny::tabPanel(
              shiny::tagList(shiny::span(class = "sb-tabicon", "\u25a6"), "Data"),
              shiny::div(style = "margin: 10px 0;",
                         shiny::downloadButton("download", download_label,
                                               class = "btn-sm")),
              shiny::div(class = "sb-hint", shiny::textOutput("n_rows")),
              shiny::tableOutput("preview"),
              shiny::uiOutput("data_notes")),
            shiny::tabPanel(
              shiny::tagList(shiny::span(class = "sb-tabicon", "\u223f"), "Graf"),
              shiny::plotOutput("plot", height = "500px")),
            shiny::tabPanel(
              shiny::tagList(shiny::span(class = "sb-tabicon", "</>"), "R-kode"),
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

    output$data_notes <- shiny::renderUI({
      notes <- attr(shiny::req(fetched()), "notes")
      if (length(notes) == 0) return(NULL)
      shiny::tags$details(
        class = "sb-notes",
        shiny::tags$summary(paste0("Noter (", length(notes), ")")),
        lapply(notes, function(n) shiny::p(n))
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
        v_num <- suppressWarnings(as.numeric(sels[[j]]))
        vals <- if (length(sels[[j]]) > 2 && !anyNA(v_num) &&
                    all(v_num == round(v_num)) && all(diff(v_num) == 1)) {
          # Consecutive whole numbers read better as from:to.
          paste0(v_num[1], ":", v_num[length(v_num)])
        } else {
          out <- paste0('"', sels[[j]], '"', collapse = ", ")
          if (length(sels[[j]]) > 1) paste0("c(", out, ")") else out
        }
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
