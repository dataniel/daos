#' Interactive explorer for the Greenland Statbank
#'
#' Launches a Shiny app for working with the Greenland Statbank
#' (bank.stat.gl). The app guides the user through three steps: find a
#' table (search the titles, or walk the subject tree in a three-column
#' browser -- parent, current, and a live preview of the item under the
#' cursor -- that also responds to `h`/`j`/`k`/`l` and the arrow keys),
#' choose values for each variable, and fetch the data. The
#' result is shown as a table and a plot, and the app always shows the
#' [daos::statbank_get()] call that reproduces the selection, so a
#' click-built query can be pasted straight into a script.
#'
#' Time variables, and numeric variables with many values (such as
#' age), are selected with from/to dropdowns. Other variables open a
#' popup with a searchable checkbox list, select/deselect-all
#' shortcuts, and a running count; an empty selection means all values.
#' The popup lists the values in the table's own (PX) order, with a link
#' to sort them alphabetically instead.
#'
#' Built as a programming aid, the settings under step 3 default to the
#' code-first shape from [daos::statbank_get()]: coded column names
#' (snake-cased), coded cells, and type conversion. Pill toggles switch
#' column names and cells between codes and texts (or "both", which adds
#' a `<column>_txt` column with the labels), turn snake-casing off, or
#' paste the full base URL into the generated call so it can be rebuilt
#' by hand. The language chooser at the top picks the language of titles,
#' labels, and texts (Greenland offers Danish, Kalaallisut, and English;
#' the Faroe Islands offer Faroese and English).
#'
#' Fetched data can be downloaded as a formatted Excel file (via
#' [daos::write_excel()] when `openxlsx2` is installed, otherwise CSV).
#' Before download, a pivot chooser can spread one variable across the
#' columns -- typically time, the layout spreadsheet users want -- with
#' the preview updating to match. The R code -- prefixed `daos::` so it
#' runs without `library(daos)` -- can be inserted into the active RStudio
#' document with "Inds\u00e6t og luk" (which closes the app) or copied; a toggle
#' lifts the variable selections into a spliced `my_query` list
#' (`!!!my_query`). The graph is interactive when `plotly` is installed:
#' with many series only the largest are highlighted and the rest greyed,
#' but every line is identifiable on hover. Pressing `Q` closes the app and
#' returns the last fetched dataset, so `df <- statbank_app()` also works
#' as a data-fetching workflow.
#'
#' The app covers both the Greenland statbank (the default) and the
#' Faroese one. The bank chooser sits one level above the subject root:
#' press `h` (or click the breadcrumb) at the root to switch bank, which
#' reloads the tree in that bank's default language.
#'
#' The table list is fetched when the app starts (one request per
#' folder in the tree) and reused for the rest of the R session.
#'
#' @param bank Statbank to open: `"gl"` (Greenland, the default) or
#'   `"fo"` (the Faroe Islands). The bank can also be switched inside
#'   the app.
#' @param lang Language of titles and labels, or `NULL` (default) for
#'   the bank's own default (Danish for Greenland, Faroese for the Faroe
#'   Islands).
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
statbank_app <- function(bank = "gl", lang = NULL) {
  for (pkg in c("curl", "jsonlite", "shiny", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required for the app. Install with {.code install.packages('{pkg}')}.")
  }
  init_bank <- bank
  init_lang <- .sb_resolve_lang(lang, bank)

  # Carries the generated code out of the app when the user asks to insert
  # it into the editor (like browse_files), delivered after runApp().
  result <- new.env(parent = emptyenv())
  result$insert <- FALSE
  result$code   <- ""

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
      margin: -15px -15px 26px -15px;
      padding: 34px 36px 30px;
      background: linear-gradient(120deg, #0a2c4f 0%, #14477e 100%);
      color: #fff;
      border-bottom: 3px solid #2f7dc0;
    }
    .sb-kicker {
      text-transform: uppercase; letter-spacing: 1.6px; font-size: 11px;
      font-weight: 700; color: #98c0e6; margin: 0 0 7px;
    }
    .sb-hero h2 {
      font-weight: 700; letter-spacing: -0.4px; margin: 0 0 6px;
      color: #fff; font-size: 27px;
    }
    .sb-sub { color: #cfe0f1; margin: 0; font-size: 15px; max-width: 660px; }
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
      display: inline-flex; width: 24px; height: 24px; border-radius: 7px;
      background: #14477e; color: #fff; align-items: center;
      justify-content: center; font-size: 13px; font-weight: 700;
      margin-right: 10px; flex: none;
    }
    .help-block, .sb-hint { color: #64748b; font-size: 12.5px; }
    .sb-count { color: #64748b; font-size: 12.5px; margin-top: -8px; margin-bottom: 12px; }
    #fetch {
      width: 100%; border: none; border-radius: 9px; font-weight: 600;
      padding: 13px 14px; font-size: 15px; letter-spacing: .2px;
      color: #fff !important; background: #14477e !important;
      box-shadow: 0 1px 2px rgba(10, 44, 79, .25); margin-top: 4px;
      transition: background .12s, box-shadow .12s;
    }
    #fetch:hover { background: #0e3a68 !important; box-shadow: 0 6px 16px rgba(10, 44, 79, .3); }
    #fetch:focus-visible { outline: 3px solid rgba(47, 125, 192, .5); outline-offset: 2px; }
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
    .sb-col-preview { background: #f8fafc; }
    .sb-col-preview .sb-colhead { color: #b6c2d1; }
    .sb-faux {
      background: #eef4fb; color: #1d62a8; font-weight: 600; cursor: default;
    }
    .sb-faux:hover { background: #eef4fb; }
    .sb-preview-tbl { padding: 10px 6px; }
    .sb-preview-tbl .sb-tblicon { font-size: 16px; }
    .sb-preview-tbl strong { color: #0f3b66; }
    .sb-item.sb-bank { font-weight: 600; }
    .sb-item.sb-bank .sb-itemmark {
      font-size: 11px; font-weight: 600; text-transform: uppercase;
      letter-spacing: .4px;
    }
    .sb-item.sb-preview-ro { cursor: default; color: #64748b; }
    .sb-item.sb-preview-ro:hover { background: transparent; }
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
      background-color: #14477e !important; color: #fff !important;
      border-color: #14477e !important;
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
    /* Settings as compact pill toggles and segmented choices, borrowed
       from browse_files: clearer than a column of checkboxes. */
    .sb-toggles { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
    .sb-toggles-label {
      font-size: 11.5px; font-weight: 700; letter-spacing: .4px;
      text-transform: uppercase; color: #64748b; margin-right: 6px;
      width: 106px; min-width: 106px; white-space: nowrap;
    }
    .sb-toggles-group {
      font-size: 11px; font-weight: 700; letter-spacing: .5px;
      text-transform: uppercase; color: #94a3b8;
      margin: 14px 0 8px; padding-top: 12px; border-top: 1px solid #eef2f7;
    }
    .sb-toggle.btn, .sb-seg.btn {
      display: inline-flex; align-items: center; gap: 7px; box-shadow: none;
      border-radius: 999px; padding: 5px 14px; font-size: 12.5px; font-weight: 600;
      color: #334155 !important; background: #fff !important;
      border: 1px solid #cbd5e1 !important; margin: 0;
    }
    .sb-toggle.btn:hover, .sb-seg.btn:hover {
      color: #14477e !important; border-color: #14477e !important; background: #f3f7fc !important;
    }
    .sb-toggle.on.btn, .sb-seg.on.btn {
      color: #0e3a68 !important; background: #dceaf8 !important;
      border-color: #14477e !important; font-weight: 700;
    }
    .sb-statusline {
      margin: 4px 0 14px; display: flex; align-items: center; gap: 7px;
      font-size: 12.5px; color: #64748b;
    }
    .sb-statusline code {
      background: rgba(15,23,42,.06); color: #334155;
      border-radius: 5px; padding: 1px 6px; font-size: 12px;
    }
    .sb-modal-sort { margin-left: auto; }
    /* A consistent, accessible button system instead of bare text links. */
    .btn { font-weight: 600; }
    .btn:focus-visible { outline: 3px solid rgba(47, 125, 192, .4); outline-offset: 2px; }
    .btn-primary {
      background-color: #14477e; border-color: #14477e; color: #fff;
    }
    .btn-primary:hover, .btn-primary:focus {
      background-color: #0e3a68; border-color: #0e3a68; color: #fff;
    }
    .sb-linkbtn {
      display: inline-flex; align-items: center; gap: 6px;
      background: #fff; border: 1px solid #d6dee8; color: #14477e;
      border-radius: 8px; padding: 5px 12px; font-size: 12.5px; font-weight: 600;
      cursor: pointer; line-height: 1.25; text-decoration: none;
      transition: border-color .12s, background .12s, color .12s;
    }
    .sb-linkbtn:hover {
      border-color: #14477e; background: #f3f7fc; color: #0e3a68; text-decoration: none;
    }
    .sb-linkbtn.on { background: #eaf1fa; border-color: #14477e; color: #0e3a68; }
    .sb-toolbar {
      display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin: 4px 0 2px;
    }
    .sb-toolbar .sb-hint { margin-left: auto; }
    /* Inputs a touch taller and calmer, for a data-tool feel. */
    .form-control, .selectize-input, .form-select {
      min-height: 38px; box-shadow: none !important;
    }
    .selectize-input.focus, .form-control:focus, .form-select:focus {
      border-color: #2f7dc0 !important; box-shadow: 0 0 0 3px rgba(47, 125, 192, .15) !important;
    }
    .sb-card, .well { padding: 22px 24px; }
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

      // The middle column is the one being navigated.
      var items = document.querySelectorAll('.sb-col-current .sb-item');
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

      // Tell the server which item is under the cursor, so the preview
      // column (right) can show its contents.
      function sendCursor(el) {
        if (!el) return;
        Shiny.setInputValue('sb_cursor', {
          full: el.getAttribute('data-full'),
          type: el.getAttribute('data-type'),
          n: Date.now()
        });
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
        sendCursor(items[nxt]);
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
        setTimeout(function() { btn.innerText = 'Kopier'; }, 1500);
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
      shiny::p(class = "sb-kicker", "Officiel statistik"),
      shiny::h2(shiny::textOutput("hero_title", inline = TRUE)),
      shiny::p(class = "sb-sub",
               "Find en tabel, v\u00e6lg dine data, og tag R-koden med hjem.")
    ),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 4,
        shiny::div(class = "sb-step",
                   shiny::span(class = "sb-badge", "1"), "Find en tabel"),
        shiny::uiOutput("lang_ui"),
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

  # An interactive plotly chart (hover to identify a line among many) when
  # plotly and scales are installed; otherwise a static ggplot.
  has_plotly <- requireNamespace("plotly", quietly = TRUE) &&
    requireNamespace("scales", quietly = TRUE)

  server <- function(input, output, session) {
    tables <- shiny::reactiveVal(NULL)

    # The active statbank and its language. Switching bank resets the
    # browser to the new bank's root and its default language.
    active_bank <- shiny::reactiveVal(init_bank)
    active_lang <- shiny::reactiveVal(init_lang)

    output$hero_title <- shiny::renderText({
      paste0(.sb_banks[[active_bank()]]$label, "s statistikbank")
    })

    shiny::observeEvent(input$quit, {
      shiny::stopApp(invisible(fetched()))
    })

    # Load the table list whenever the bank or language changes (also at
    # startup); both feed the tree labels and the table titles.
    shiny::observe({
      bk <- active_bank()
      lg <- active_lang()
      shiny::withProgress(
        message = paste0("Henter tabelliste fra ", .sb_banks[[bk]]$label, " ..."), {
          tables(statbank_tables(lang = lg, bank = bk))
        })
    })

    # Language chooser: the languages the active bank offers, with the
    # current one selected. Picking another reloads everything in it.
    output$lang_ui <- shiny::renderUI({
      langs <- .sb_banks[[active_bank()]]$langs
      shiny::selectInput(
        "lang", "Sprog",
        choices  = stats::setNames(langs, .sb_lang_label(langs)),
        selected = shiny::isolate(active_lang()))
    })
    shiny::observeEvent(input$lang, {
      if (!identical(input$lang, active_lang())) active_lang(input$lang)
    })

    # Node listings for the tree browser, cached per bank, language, and
    # folder.
    node_cache <- new.env(parent = emptyenv())
    nodes_cached <- function(path, b, lg) {
      key <- paste0(b, "|", lg, "|", if (nzchar(path)) path else ".")
      if (is.null(node_cache[[key]])) {
        node_cache[[key]] <- statbank_nodes(path, lang = lg, bank = b)
      }
      node_cache[[key]]
    }
    get_nodes <- function(path) nodes_cached(path, active_bank(), active_lang())

    # Bank switching. Picking the active bank just leaves the chooser;
    # picking another resets path, table, and language.
    at_banks <- shiny::reactiveVal(FALSE)
    shiny::observeEvent(input$go_banks, at_banks(TRUE))
    shiny::observeEvent(input$pick_bank, {
      at_banks(FALSE)
      if (input$pick_bank != active_bank()) {
        current_table(NULL)
        cur_path("")
        active_lang(.sb_banks[[input$pick_bank]]$default_lang)
        active_bank(input$pick_bank)
        shiny::updateTextInput(session, "search", value = "")
      }
    })

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

    # The item under the cursor in the middle column. The preview (right)
    # column shows its contents. JS moves the cursor and reports here;
    # changing folder resets it to the first node so the preview matches
    # the initial render.
    cursor <- shiny::reactiveVal(NULL)

    # Reset the cursor to the first row whenever the level changes: a new
    # folder, a new bank, or entering the bank chooser. JS then moves it
    # on j/k and reports back via input$sb_cursor.
    shiny::observe({
      if (at_banks()) {
        cursor(list(full = names(.sb_banks)[1], type = "bank"))
      } else {
        path  <- cur_path()
        nodes <- get_nodes(path)
        if (nrow(nodes) > 0) {
          full <- if (nzchar(path)) paste(path, nodes$id[1], sep = "/") else nodes$id[1]
          cursor(list(full = full, type = nodes$type[1]))
        } else {
          cursor(NULL)
        }
      }
    })

    shiny::observeEvent(input$sb_cursor, {
      cursor(list(full = input$sb_cursor$full, type = input$sb_cursor$type))
    })

    meta <- shiny::reactive({
      shiny::req(current_table())
      statbank_meta(current_table(), lang = active_lang(), bank = active_bank())
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
                c(list(m$path), sels,
                  list(lang = active_lang(), bank = active_bank(), .type_convert = FALSE))),
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
    modal_var  <- shiny::reactiveVal(NULL)
    working    <- shiny::reactiveVal(character())
    modal_sort <- shiny::reactiveVal(FALSE)   # alphabetical vs PX order

    open_observers <- list()
    shiny::observeEvent(meta(), {
      lapply(open_observers, function(o) o$destroy())
      vars <- meta()$variables
      obs <- lapply(seq_len(nrow(vars)), function(j) {
        if (is_range_var(vars, j)) return(NULL)
        shiny::observeEvent(input[[paste0("sbopen_", j)]], {
          modal_var(j)
          modal_sort(FALSE)
          cur <- sel_store()[[vars$code[j]]]
          working(if (is.null(cur)) character() else cur)
          shiny::showModal(shiny::modalDialog(
            title = vars$text[j],
            shiny::textInput("modal_filter", NULL,
                             placeholder = "Filtrer (regex), fx ^20|i alt"),
            shiny::div(
              class = "sb-toolbar",
              shiny::actionButton("modal_all", "V\u00e6lg alle viste", class = "sb-linkbtn"),
              shiny::actionButton("modal_none", "Frav\u00e6lg alle viste", class = "sb-linkbtn"),
              shiny::actionButton("modal_sort",
                                  shiny::textOutput("modal_sort_lbl", inline = TRUE),
                                  class = "sb-linkbtn"),
              shiny::span(class = "sb-hint sb-modal-sort",
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
        pat  <- input$modal_filter
        # The filter is a case-insensitive regex; a half-typed or invalid
        # pattern falls back to a plain substring so the list never errors.
        keep <- tryCatch(
          grepl(pat, texts, ignore.case = TRUE) |
            grepl(pat, codes, ignore.case = TRUE),
          error = function(e) {
            p <- tolower(pat)
            grepl(p, tolower(texts), fixed = TRUE) |
              grepl(p, tolower(codes), fixed = TRUE)
          }
        )
        codes <- codes[keep]
        texts <- texts[keep]
      }
      # PX order by default; the sort link switches to alphabetical.
      if (modal_sort()) {
        ord   <- order(texts)
        codes <- codes[ord]
        texts <- texts[ord]
      }
      stats::setNames(codes, texts)
    })

    shiny::observeEvent(input$modal_sort, modal_sort(!modal_sort()))
    output$modal_sort_lbl <- shiny::renderText(
      if (modal_sort()) "PX-orden" else "Sort\u00e9r A\u2013\u00c5")

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

    # Output settings, held in reactiveVals so the pill toggles can show
    # their state. Defaults favour codes, since the app is a programming
    # aid: coded column names and cells, snake-cased names, conversion on.
    o_codecols <- shiny::reactiveVal(TRUE)    # codes vs texts as column names
    o_values   <- shiny::reactiveVal("code")  # "code" | "text" | "both"
    o_clean    <- shiny::reactiveVal(TRUE)    # snake_case the column names
    o_typeconv <- shiny::reactiveVal(TRUE)    # readr::type_convert the result
    o_fullurl  <- shiny::reactiveVal(FALSE)   # paste the base URL into the code
    o_splice   <- shiny::reactiveVal(FALSE)   # selections as a spliced list2

    shiny::observeEvent(input$set_colcode, o_codecols(TRUE))
    shiny::observeEvent(input$set_coltext, o_codecols(FALSE))
    shiny::observeEvent(input$set_valcode, o_values("code"))
    shiny::observeEvent(input$set_valtext, o_values("text"))
    shiny::observeEvent(input$set_valboth, o_values("both"))
    shiny::observeEvent(input$set_clean_on,   o_clean(TRUE))
    shiny::observeEvent(input$set_clean_off,  o_clean(FALSE))
    shiny::observeEvent(input$set_type_auto,  o_typeconv(TRUE))
    shiny::observeEvent(input$set_type_text,  o_typeconv(FALSE))
    shiny::observeEvent(input$set_url_short,  o_fullurl(FALSE))
    shiny::observeEvent(input$set_url_full,   o_fullurl(TRUE))
    shiny::observeEvent(input$set_var_inline, o_splice(FALSE))
    shiny::observeEvent(input$set_var_list,   o_splice(TRUE))

    output$fetch_area <- shiny::renderUI({
      shiny::req(meta())
      seg <- function(id, label, active) shiny::actionButton(
        id, label, class = paste("sb-seg btn", if (active) "on"))
      row <- function(label, ...) shiny::div(
        class = "sb-toggles",
        shiny::span(class = "sb-toggles-label", label), ...)
      shiny::tagList(
        shiny::div(class = "sb-step",
                   shiny::span(class = "sb-badge", "3"), "Hent"),
        row("Kolonnenavne",
            seg("set_colcode", "Koder", o_codecols()),
            seg("set_coltext", "Tekster", !o_codecols())),
        row("Celleindhold",
            seg("set_valcode", "Koder", o_values() == "code"),
            seg("set_valtext", "Tekster", o_values() == "text"),
            seg("set_valboth", "Begge", o_values() == "both")),
        row("Navneformat",
            seg("set_clean_on", "snake_case", o_clean()),
            seg("set_clean_off", "U\u00e6ndret", !o_clean())),
        row("Kolonnetyper",
            seg("set_type_auto", "Automatisk", o_typeconv()),
            seg("set_type_text", "Som tekst", !o_typeconv())),
        shiny::div(class = "sb-toggles-group", "R-kode"),
        row("URL i koden",
            seg("set_url_short", "Kort", !o_fullurl()),
            seg("set_url_full", "Fuld", o_fullurl())),
        row("Variabler",
            seg("set_var_inline", "Inline", !o_splice()),
            seg("set_var_list", "Som liste", o_splice())),
        shiny::div(class = "sb-statusline",
                   shiny::uiOutput("settings_hint", inline = TRUE)),
        shiny::actionButton("fetch", "Hent data", class = "btn-primary")
      )
    })

    # A one-line summary of what the current settings produce.
    output$settings_hint <- shiny::renderUI({
      cols  <- if (o_codecols()) "kodenavne" else "tekstnavne"
      cells <- switch(o_values(),
                      code = "koder i cellerne",
                      text = "tekster i cellerne",
                      both = "koder + _txt-tekstkolonner")
      shiny::tagList(
        shiny::HTML("&rarr;"),
        paste0(cols, ", ", cells, if (o_clean()) ", snake_case" else ""))
    })

    # Option getters used by the fetch and the code preview.
    opt_col_names <- function() if (o_codecols()) "code" else "text"
    opt_values    <- function() o_values()
    opt_clean     <- function() o_clean()
    opt_typeconv  <- function() o_typeconv()

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
          list(lang = active_lang(), bank = active_bank(),
               .col_names = opt_col_names(),
               .values = opt_values(),
               .clean_names = opt_clean(),
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
          `data-full` = full, `data-type` = "l",
          onclick = sprintf(
            "Shiny.setInputValue('browse_to', '%s', {priority: 'event'})", full),
          row$text,
          shiny::span(class = "sb-itemmark", mark)
        )
      } else {
        shiny::div(
          class = paste(c("sb-item sb-tbl", if (cursor) "cursor"), collapse = " "),
          `data-full` = full, `data-type` = "t",
          onclick = sprintf(
            "Shiny.setInputValue('pick_table', '%s', {priority: 'event'})", full),
          shiny::span(class = "sb-tblicon", "\u25a6"),
          row$text
        )
      }
    }

    # A row in the bank chooser (the level above the subject root).
    bank_item <- function(id, active = FALSE, cursor = FALSE) {
      shiny::div(
        class = paste(c("sb-item sb-bank", if (active) "active", if (cursor) "cursor"),
                      collapse = " "),
        `data-full` = id, `data-type` = "bank",
        onclick = sprintf(
          "Shiny.setInputValue('pick_bank', '%s', {priority: 'event'})", id),
        .sb_banks[[id]]$label,
        if (active) shiny::span(class = "sb-itemmark", "aktiv")
      )
    }

    # The preview column: contents of the folder under the cursor, the
    # subjects of the bank under the cursor, or a card for the table.
    output$preview_col <- shiny::renderUI({
      cur <- cursor()
      if (is.null(cur)) return(NULL)
      tbl <- tables()
      if (identical(cur$type, "bank")) {
        subs <- nodes_cached("", cur$full, .sb_banks[[cur$full]]$default_lang)
        shiny::tagList(
          shiny::p(class = "sb-hint", style = "padding: 4px 8px;",
                   paste0("Emner i ", .sb_banks[[cur$full]]$label, ":")),
          lapply(seq_len(nrow(subs)), function(i) {
            shiny::div(class = "sb-item sb-preview-ro", subs$text[i])
          })
        )
      } else if (identical(cur$type, "l")) {
        kids <- get_nodes(cur$full)
        if (nrow(kids) == 0) {
          return(shiny::p(class = "sb-hint", style = "padding: 8px;", "Tom mappe."))
        }
        lapply(seq_len(nrow(kids)), function(i) browse_item(kids[i, ], cur$full, tbl = tbl))
      } else {
        row <- if (!is.null(tbl)) tbl[paste(tbl$path, tbl$id, sep = "/") == cur$full, ] else tbl[0, ]
        if (is.null(row) || nrow(row) == 0) return(NULL)
        shiny::div(
          class = "sb-preview-tbl",
          shiny::p(shiny::span(class = "sb-tblicon", "\u25a6"),
                   shiny::strong(row$title[1])),
          shiny::p(class = "sb-hint",
                   paste0("Tabel ", row$id[1],
                          if (!is.na(row$updated[1]))
                            paste0(" \u00b7 senest opdateret ", substr(row$updated[1], 1, 10)))),
          shiny::p(class = "sb-hint", "Tryk l/Enter eller klik for at v\u00e6lge tabellen.")
        )
      }
    })

    # The main panel walks through three states: the tree browser, a
    # prompt to pick values, and the results.
    output$main_area <- shiny::renderUI({
      if (is.null(current_table())) {
        banks_ids <- names(.sb_banks)

        # Right column is always the live preview.
        preview_col <- shiny::div(
          class = "sb-col sb-col-preview",
          shiny::div(class = "sb-colhead", "Forh\u00e5ndsvisning"),
          shiny::uiOutput("preview_col")
        )

        # The bank chooser: the level above every subject root.
        if (at_banks()) {
          bank_col <- shiny::div(
            class = "sb-col sb-col-current",
            shiny::div(class = "sb-colhead", "Statistikbank"),
            lapply(seq_along(banks_ids), function(i) {
              bank_item(banks_ids[i], active = banks_ids[i] == active_bank(),
                        cursor = i == 1)
            })
          )
          faux_col <- shiny::div(
            class = "sb-col sb-col-parent",
            shiny::div(class = "sb-colhead", "Niveau op"),
            shiny::div(class = "sb-item sb-faux", "Nordatlanten")
          )
          return(shiny::div(
            class = "sb-card",
            shiny::h4("V\u00e6lg statistikbank"),
            shiny::p(class = "sb-hint",
                     "V\u00e6lg hvilken statistikbank du vil arbejde med. Gr\u00f8nland er",
                     " standard, og du kan altid skifte igen ved at g\u00e5 et niveau op (h)."),
            shiny::div(class = "sb-crumbs",
                       shiny::tags$a(
                         onclick = "Shiny.setInputValue('go_banks', Date.now())",
                         "Statistikbank")),
            shiny::div(class = "sb-browser", faux_col, bank_col, preview_col)
          ))
        }

        path <- cur_path()
        segs <- if (nzchar(path)) strsplit(path, "/", fixed = TRUE)[[1]] else character()

        # Breadcrumb: bank chooser, then the bank, then the folders.
        crumbs <- list(
          shiny::tags$a(onclick = "Shiny.setInputValue('go_banks', Date.now())",
                        "Statistikbank"),
          shiny::span(class = "sb-sep", "/"),
          shiny::tags$a(onclick = "Shiny.setInputValue('browse_to', '', {priority: 'event'})",
                        .sb_banks[[active_bank()]]$label))
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

        # Middle column: the current folder, cursor on the first row.
        # JS owns the cursor after that and reports moves to the server.
        cur_col <- shiny::div(
          class = "sb-col sb-col-current",
          shiny::div(class = "sb-colhead", "Indhold"),
          lapply(seq_len(nrow(cur_nodes)), function(i) {
            browse_item(cur_nodes[i, ], path, cursor = i == 1, tbl = tbl)
          })
        )

        # Left column: one level up. At the subject root that is the bank
        # list, with the active bank highlighted (click to switch);
        # deeper, it is the parent folder.
        parent_col <- if (nzchar(path)) {
          parent_path  <- if (grepl("/", path, fixed = TRUE)) sub("/[^/]+$", "", path) else ""
          parent_nodes <- get_nodes(parent_path)
          shiny::div(
            class = "sb-col sb-col-parent",
            shiny::div(class = "sb-colhead", "Niveau op"),
            lapply(seq_len(nrow(parent_nodes)), function(i) {
              browse_item(parent_nodes[i, ], parent_path,
                          active = parent_nodes$id[i] == segs[length(segs)],
                          tbl = tbl)
            })
          )
        } else {
          shiny::div(
            class = "sb-col sb-col-parent",
            shiny::div(class = "sb-colhead", "Statistikbank"),
            lapply(seq_along(banks_ids), function(i) {
              bank_item(banks_ids[i], active = banks_ids[i] == active_bank())
            })
          )
        }

        columns <- shiny::div(class = "sb-browser", parent_col, cur_col, preview_col)

        return(shiny::div(
          class = "sb-card",
          shiny::h4(paste0("Gennemse ", .sb_banks[[active_bank()]]$label, "s statistikbank")),
          shiny::p(class = "sb-hint",
                   "Tre kolonner: et niveau op, hvor du st\u00e5r, og en forh\u00e5ndsvisning",
                   " af det, mark\u00f8ren peger p\u00e5. Klik dig ned gennem emnerne, og klik",
                   " p\u00e5 en tabel for at v\u00e6lge den. Du kan ogs\u00e5 bruge s\u00f8gefeltet til venstre.",
                   " Tastatur: j/k eller pil op/ned flytter mark\u00f8ren, l/Enter \u00e5bner,",
                   " h eller pil venstre g\u00e5r et niveau op -- helt op til valg af statistikbank."),
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
                     "Data hentes direkte fra statistikbanken (Gr\u00f8nland: bank.stat.gl,",
                     " F\u00e6r\u00f8erne: statbank.hagstova.fo).",
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
        shiny::actionButton("back_to_browse", "\u2190 Tilbage til oversigten",
                            class = "sb-linkbtn", style = "margin-bottom: 14px;"),
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
              shiny::div(
                style = "display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap; margin: 10px 0;",
                shiny::div(style = "min-width: 240px;", shiny::uiOutput("pivot_ui")),
                shiny::downloadButton("download", download_label, class = "btn-sm")),
              shiny::div(class = "sb-hint", shiny::textOutput("n_rows")),
              shiny::tableOutput("preview"),
              shiny::uiOutput("data_notes")),
            shiny::tabPanel(
              shiny::tagList(shiny::span(class = "sb-tabicon", "\u223f"), "Graf"),
              shiny::div(class = "sb-hint", style = "margin: 8px 0 4px;",
                         shiny::textOutput("plot_caption")),
              if (has_plotly) plotly::plotlyOutput("plot", height = "520px")
              else shiny::plotOutput("plot", height = "520px")),
            shiny::tabPanel(
              shiny::tagList(shiny::span(class = "sb-tabicon", "</>"), "R-kode"),
                            shiny::p(class = "sb-hint",
                                     "Kopier koden ind i dit script for at gentage udtr\u00e6kket uden appen:"),
                            shiny::div(
                              style = "margin-bottom: 8px;",
                              shiny::actionButton(
                                "do_insert_code", "Inds\u00e6t og luk",
                                class = "btn btn-primary btn-sm"),
                              shiny::tags$button(
                                class = "btn btn-default btn-sm",
                                style = "margin-left: 8px;",
                                onclick = "sbCopyCode(this);",
                                "Kopier"
                              )
                            ),
                            shiny::verbatimTextOutput("code"))
          )
        }
      )
    })

    # Insert the generated code into the active RStudio document and close;
    # delivery happens after runApp(). The last fetched data still returns.
    shiny::observeEvent(input$do_insert_code, {
      result$code   <- gen_code()
      result$insert <- TRUE
      shiny::stopApp(invisible(fetched()))
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

    # Pivot chooser: spread one variable across the columns before
    # download/preview (Excel users often want time on the columns). The
    # _txt duplicate of each variable is left out of the options.
    output$pivot_ui <- shiny::renderUI({
      d <- shiny::req(fetched())
      cols <- setdiff(names(d), "value")
      cols <- cols[!grepl("_txt$", cols) | !sub("_txt$", "", cols) %in% cols]
      shiny::selectInput(
        "pivot_col", "Pivot: spred en variabel ud p\u00e5 kolonner",
        choices = c("Ingen (lang form)" = "", stats::setNames(cols, cols)),
        selected = "")
    })

    # The data as downloaded/previewed: long by default, wide when a pivot
    # variable is chosen.
    download_data <- shiny::reactive({
      d <- shiny::req(fetched())
      if (shiny::isTruthy(input$pivot_col)) .sb_pivot_wide(d, input$pivot_col) else d
    })

    output$n_rows <- shiny::renderText({
      d <- download_data()
      base <- if (nrow(d) > 100) paste0("Viser de f\u00f8rste 100 af ", nrow(d), " r\u00e6kker.")
              else paste(nrow(d), "r\u00e6kker.")
      if (shiny::isTruthy(input$pivot_col))
        base <- paste0(base, " Pivoteret: ", input$pivot_col, " p\u00e5 kolonnerne.")
      base
    })

    output$preview <- shiny::renderTable({
      d <- utils::head(download_data(), 100)
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
        d <- shiny::req(download_data())
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

    # Plot data: a tidy frame with a time x, a numeric value, a series
    # label, and a hover string. The series label is built from the other
    # variables; with .values = "both" each variable has a code and a
    # <code>_txt column, so the readable _txt one is kept for the label
    # and its code sibling dropped.
    plot_data <- shiny::reactive({
      d    <- shiny::req(fetched())
      vars <- meta()$variables
      time_idx <- which(vars$time | tolower(vars$code) == "time" |
                          tolower(vars$text) == "tid")
      shiny::validate(shiny::need(length(time_idx) > 0,
        "Tabellen har ingen tidsvariabel at plotte over."))
      base_nm  <- if (o_codecols()) vars$code[time_idx[1]] else tolower(vars$text[time_idx[1]])
      cand     <- unique(c(base_nm, .sb_clean_names(base_nm)))
      time_col <- intersect(cand, names(d))[1]
      shiny::validate(shiny::need(!is.na(time_col),
        "Tidsvariablen indg\u00e5r ikke i udtr\u00e6kket."))

      group_cols <- setdiff(names(d), c(time_col, paste0(time_col, "_txt"), "value"))
      group_cols <- group_cols[!(paste0(group_cols, "_txt") %in% group_cols)]
      grp <- if (length(group_cols) > 0) {
        do.call(paste, c(lapply(group_cols, function(g) as.character(d[[g]])),
                         sep = " \u00b7 "))
      } else rep("serie", nrow(d))

      tlab <- as.character(d[[time_col]])
      tnum <- suppressWarnings(as.numeric(tlab))
      x    <- if (!anyNA(tnum)) tnum else factor(tlab, levels = unique(tlab))
      vfmt <- format(d$value, big.mark = ".", decimal.mark = ",",
                     trim = TRUE, scientific = FALSE)

      list(
        d = tibble::tibble(x = x, value = d$value, grp = grp,
                           tip = paste0(grp, "<br>", tlab, ": ", vfmt)),
        time_lab = vars$text[time_idx[1]],
        n_series = length(unique(grp))
      )
    })

    # Eight-colour palette; series beyond it are greyed and only the top
    # eight by average level are highlighted, so a wide table still reads.
    sb_palette <- c("#0f172a", "#1d62a8", "#10b981", "#f59e0b",
                    "#ef4444", "#8b5cf6", "#06b6d4", "#ec4899")

    build_plot <- function(interactive) {
      pd <- plot_data(); d <- pd$d; n <- pd$n_series
      aes_hi <- if (interactive)
        ggplot2::aes(x = .data$x, y = .data$value, colour = .data$grp,
                     group = .data$grp, text = .data$tip)
      else
        ggplot2::aes(x = .data$x, y = .data$value, colour = .data$grp,
                     group = .data$grp)

      if (n <= length(sb_palette)) {
        cols <- stats::setNames(rep_len(sb_palette, n), unique(d$grp))
        p <- ggplot2::ggplot(d, aes_hi) +
          ggplot2::geom_line(linewidth = 0.9) +
          # Markers help when there are few series and few periods; drop
          # them once the series get dense so the lines stay clean.
          (if (n <= 4) ggplot2::geom_point(size = 1.4) else NULL) +
          ggplot2::scale_colour_manual(values = cols)
        legend_pos <- if (n > 1) "top" else "none"
      } else {
        means <- tapply(d$value, d$grp, mean, na.rm = TRUE)
        top   <- names(sort(means, decreasing = TRUE))[seq_len(length(sb_palette))]
        ctx   <- d[!d$grp %in% top, , drop = FALSE]
        hi    <- d[d$grp %in% top, , drop = FALSE]
        hi$grp <- factor(hi$grp, levels = top)
        aes_ctx <- if (interactive)
          ggplot2::aes(x = .data$x, y = .data$value, group = .data$grp, text = .data$tip)
        else
          ggplot2::aes(x = .data$x, y = .data$value, group = .data$grp)
        p <- ggplot2::ggplot() +
          ggplot2::geom_line(data = ctx, aes_ctx, colour = "#dbe3ec", linewidth = 0.5) +
          ggplot2::geom_line(data = hi, aes_hi, linewidth = 1) +
          ggplot2::scale_colour_manual(
            values = stats::setNames(rep_len(sb_palette, length(top)), top))
        legend_pos <- "top"
      }

      if (has_plotly)
        p <- p + ggplot2::scale_y_continuous(
          labels = scales::label_number(big.mark = ".", decimal.mark = ","))
      p +
        ggplot2::labs(x = pd$time_lab, y = "value", colour = NULL) +
        ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(
          panel.grid.minor   = ggplot2::element_blank(),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.major.y = ggplot2::element_line(colour = "#e5e9f0"),
          axis.title         = ggplot2::element_text(colour = "#1e293b", size = 12.5),
          axis.text          = ggplot2::element_text(colour = "#334155"),
          legend.text        = ggplot2::element_text(colour = "#1e293b", size = 11.5),
          legend.title       = ggplot2::element_blank(),
          legend.position    = legend_pos
        )
    }

    output$plot_caption <- shiny::renderText({
      n <- plot_data()$n_series
      if (n <= length(sb_palette)) return("")
      paste0(n, " serier i alt \u2014 de ", length(sb_palette),
             " st\u00f8rste er fremh\u00e6vet, resten er gr\u00e5.",
             " Hold musen over en linje for at se hvilken.")
    })

    if (has_plotly) {
      output$plot <- plotly::renderPlotly({
        plotly::ggplotly(build_plot(TRUE), tooltip = "text") |>
          plotly::layout(
            legend = list(orientation = "h", y = 1.12, x = 0, title = list(text = "")),
            hoverlabel = list(bgcolor = "white", bordercolor = "#cbd5e1",
                              font = list(family = "Segoe UI, sans-serif",
                                          color = "#1e293b", size = 12)),
            # A faint vertical guide line on hover, to read a period across
            # all the series at once.
            xaxis = list(showspikes = TRUE, spikemode = "across", spikesnap = "cursor",
                         spikethickness = 1, spikedash = "dot", spikecolor = "#cbd5e1"),
            paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") |>
          plotly::config(displayModeBar = "hover", displaylogo = FALSE,
                         modeBarButtonsToRemove = list("select2d", "lasso2d",
                                                       "autoScale2d", "hoverClosestCartesian",
                                                       "hoverCompareCartesian"))
      })
    } else {
      output$plot <- shiny::renderPlot(build_plot(FALSE))
    }

    # The statbank_get() call that reproduces the selection (one argument
    # per line), optionally with the variable selections lifted into a
    # spliced `my_query` list. Prefixed daos:: so it runs without
    # library(daos).
    gen_code <- shiny::reactive({
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
        paste0(nm, " = ", vals)
      }, character(1))
      args <- args[!is.na(args)]

      b <- .sb_banks[[active_bank()]]
      bank_opts <- if (o_fullurl()) {
        # The resolved base URL, so the call is self-contained and can be
        # rebuilt by hand; the URL already carries the language.
        paste0('bank = "', b$base, "/", active_lang(), "/", b$db, '"')
      } else {
        c(
          if (active_bank() != "gl") paste0('bank = "', active_bank(), '"'),
          if (active_lang() != b$default_lang) paste0('lang = "', active_lang(), '"')
        )
      }
      opts <- c(
        bank_opts,
        if (!o_codecols()) '.col_names = "text"',
        if (o_values() == "text") '.values = "text"',
        if (o_values() == "both") '.values = "both"',
        if (!o_clean()) '.clean_names = FALSE',
        if (!o_typeconv()) '.type_convert = FALSE'
      )

      # With splice on (and at least one selection), the variables move into
      # a `my_query` list passed with !!! -- which works because
      # statbank_get() gathers ... with rlang::list2().
      ind <- function(x) paste0("  ", x)
      if (o_splice() && length(args) > 0) {
        pre  <- paste0("my_query <- list(\n", paste(ind(args), collapse = ",\n"), "\n)\n\n")
        body <- c(paste0('"', meta()$path, '"'), "!!!my_query", opts)
      } else {
        pre  <- ""
        body <- c(paste0('"', meta()$path, '"'), args, opts)
      }
      paste0(pre, "df <- daos::statbank_get(\n",
             paste(ind(body), collapse = ",\n"), "\n)")
    })

    output$code <- shiny::renderText(gen_code())
  }

  out <- shiny::runApp(shiny::shinyApp(ui, server), quiet = TRUE)

  # Deliver the code after the app has closed, so the active document is the
  # user's script/console again, not the app viewer (as in browse_files()).
  if (result$insert && nzchar(result$code)) {
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      rstudioapi::insertText(result$code)
    } else if (.Platform$OS.type == "windows") {
      utils::writeClipboard(result$code)
      cli::cli_alert_info("Ikke i RStudio -- koden er kopieret til udklipsholderen i stedet.")
    } else {
      cli::cli_alert_info("Ikke i RStudio -- returnerer det seneste udtr\u00e6k.")
    }
  }
  invisible(out)
}
