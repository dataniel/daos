# A Shiny front-end for the task_* client. It works entirely through the
# exported functions against a shared SQLite file, so several people can
# open the same database at once and see each other's changes on refresh.

#' Task manager app
#'
#' Launches a Shiny app for a shared task database: add, complete, edit,
#' delete, and annotate tasks, filter by person, project, tag, and status,
#' and see project and people overviews. Because it works against a shared
#' SQLite file (see [daos::task_db()]), several people can point at the
#' same file and get a live view; the app re-reads the database on a timer
#' and after every change.
#'
#' @param db Path to the task database. **Created if it does not exist**,
#'   so pointing at a fresh path just starts a new shared database. Can
#'   also be switched inside the app.
#'
#' @return Runs the app; returns nothing.
#'
#' @examples
#' \dontrun{
#' task_app("tasks.sqlite")
#' }
#'
#' @seealso [daos::task_add()], [daos::task_list()]
#'
#' @importFrom cli cli_abort
#' @export
task_app <- function(db = "tasks.sqlite") {
  for (pkg in c("shiny", "DBI", "RSQLite")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required for the app. Install with {.code install.packages(c('shiny','DBI','RSQLite'))}.")
  }
  task_db(db)
  start_db <- normalizePath(db, winslash = "/", mustWork = FALSE)

  theme <- if (requireNamespace("bslib", quietly = TRUE)) {
    tryCatch(bslib::bs_theme(version = 5, bootswatch = "zephyr"),
             error = function(e) NULL)
  }

  css <- "
    body { background: #eef1f6; font-family: -apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif; color: #1e293b; }
    .container-fluid { max-width: 1240px; }
    .tk-hero {
      position: relative; margin: -15px -15px 22px -15px; padding: 26px 34px 24px;
      background: radial-gradient(120% 140% at 0% 0%, #1d62a8 0%, #0c3a63 60%, #0a3157 100%);
      color: #fff; box-shadow: 0 6px 22px rgba(12,58,99,.25);
    }
    .tk-hero-text h2 { font-weight: 800; margin: 0 0 4px; color: #fff; font-size: 23px; letter-spacing: -.4px; }
    .tk-hero .tk-db { color: #b7d0ea; font-size: 12.5px; word-break: break-all; }
    .tk-hero-actions { position: absolute; top: 22px; right: 30px; display: flex; gap: 8px; }
    .tk-ghost {
      background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.22);
      color: #eef5fc; font-weight: 600; font-size: 13px; border-radius: 9px; padding: 6px 14px;
      transition: background .12s, border-color .12s;
    }
    .tk-ghost:hover { background: rgba(255,255,255,.22); color: #fff; border-color: rgba(255,255,255,.4); }
    .tk-ghost-quit:hover { background: rgba(248,113,113,.28); border-color: rgba(248,113,113,.5); }
    .tk-card { background: #fff; border: 1px solid #e6eaf1; border-radius: 16px;
      box-shadow: 0 1px 2px rgba(15,23,42,.04), 0 8px 24px rgba(15,23,42,.06); padding: 20px; margin-bottom: 18px; }
    .tk-card h4 { font-weight: 700; font-size: 14px; margin: 0 0 14px; color: #0f172a;
      display: flex; align-items: center; gap: 8px; }
    .tk-card h4::before { content: ''; width: 4px; height: 16px; border-radius: 3px; background: #1d62a8; }
    label { font-weight: 600; font-size: 12.5px; color: #475569; margin-bottom: 4px; }
    .form-control, .selectize-input, .form-select {
      border-radius: 9px !important; border-color: #dbe1ea !important; font-size: 14px;
    }
    .form-control:focus, .selectize-input.focus, .form-select:focus {
      border-color: #1d62a8 !important; box-shadow: 0 0 0 3px rgba(29,98,168,.12) !important;
    }
    .btn { border-radius: 9px; font-weight: 600; }
    .btn-primary { background: #1d62a8; border-color: #1d62a8; box-shadow: 0 2px 8px rgba(29,98,168,.30); }
    .btn-primary:hover { background: #174e86; border-color: #174e86; }
    #add { padding: 9px; font-size: 14.5px; }
    .tk-stats { display: flex; gap: 14px; margin-bottom: 18px; }
    .tk-stat { flex: 1; background: #fff; border: 1px solid #e6eaf1; border-radius: 14px; padding: 14px 18px;
      box-shadow: 0 1px 2px rgba(15,23,42,.04), 0 6px 18px rgba(15,23,42,.05); }
    .tk-stat .tk-n { font-size: 26px; font-weight: 800; color: #0f172a; line-height: 1.1; }
    .tk-stat .tk-l { font-size: 11.5px; color: #64748b; text-transform: uppercase; letter-spacing: .5px; font-weight: 700; margin-top: 2px; }
    .tk-stat.tk-over { border-color: #fecaca; background: #fff5f5; }
    .tk-stat.tk-over .tk-n { color: #dc2626; }
    .tk-rows { display: flex; flex-direction: column; gap: 7px; }
    .tk-row { display: flex; align-items: center; gap: 12px; padding: 11px 13px; border: 1px solid #e8edf3;
      border-radius: 12px; cursor: pointer; background: #fff; transition: border-color .12s, box-shadow .12s, transform .08s; }
    .tk-row:hover { border-color: #b9cde6; box-shadow: 0 2px 10px rgba(15,23,42,.07); }
    .tk-row.selected { border-color: #1d62a8; box-shadow: 0 0 0 3px rgba(29,98,168,.16); }
    .tk-urg { flex: none; width: 44px; height: 32px; display: flex; align-items: center; justify-content: center;
      font-weight: 800; font-size: 13.5px; color: #1d62a8; background: #eef4fc; border-radius: 8px; }
    .tk-main { flex: 1; min-width: 0; }
    .tk-desc { font-weight: 600; color: #0f172a; }
    .tk-meta { margin-top: 3px; display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
    .tk-chip { font-size: 11.5px; border-radius: 999px; padding: 2px 10px; background: #eef2f7; color: #475569; font-weight: 500; }
    .tk-chip.tk-proj { background: #e0ecfb; color: #1d62a8; font-weight: 600; }
    .tk-chip.tk-person { background: #ede9fe; color: #6d28d9; font-weight: 600; }
    .tk-chip.tk-tag { background: #f1f5f9; }
    .tk-chip.tk-tag::before { content: '#'; opacity: .5; }
    .tk-pri { flex: none; font-size: 11px; font-weight: 700; border-radius: 6px; padding: 2px 7px; }
    .tk-pri-H { background: #fee2e2; color: #b91c1c; }
    .tk-pri-M { background: #fef3c7; color: #b45309; }
    .tk-pri-L { background: #e0e7ff; color: #4338ca; }
    .tk-due { flex: none; font-size: 12.5px; color: #64748b; font-weight: 600; white-space: nowrap; }
    .tk-due.tk-soon { color: #b45309; }
    .tk-due.tk-over { color: #dc2626; }
    .tk-blocked { flex: none; font-size: 11.5px; color: #b91c1c; background: #fee2e2; border-radius: 6px; padding: 2px 8px; font-weight: 600; }
    .tk-ann { flex: none; font-size: 12px; color: #94a3b8; }
    .tk-empty { text-align: center; padding: 36px 12px; color: #64748b; }
    .tk-empty-ico { font-size: 32px; margin-bottom: 8px; }
    .tk-detail .tk-d-row { display: flex; justify-content: space-between; padding: 5px 0; border-bottom: 1px solid #f1f5f9; font-size: 13.5px; }
    .tk-detail .tk-d-row:last-child { border-bottom: none; }
    .tk-detail .tk-d-k { color: #64748b; }
    .tk-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
    .tk-note { font-size: 12.5px; color: #475569; padding: 6px 0; border-bottom: 1px dashed #e2e8f0; }
    .tk-note .tk-note-t { color: #94a3b8; font-size: 11px; }
    .nav-pills { margin-bottom: 14px; gap: 8px; }
    .nav-pills .nav-link { font-weight: 600; color: #334155; background: #fff; border: 1px solid #e6eaf1;
      border-radius: 10px; padding: 7px 18px; box-shadow: 0 1px 2px rgba(15,23,42,.04); }
    .nav-pills .nav-link:hover { border-color: #b9cde6; color: #1d62a8; }
    .nav-pills .nav-link.active { background-color: #1d62a8 !important; color: #fff !important; border-color: #1d62a8 !important; }
    .tk-proj-row { padding: 13px 4px; border-bottom: 1px solid #f1f5f9; }
    .tk-proj-row:last-child { border-bottom: none; }
    .tk-proj-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 7px; }
    .tk-proj-name { font-weight: 600; color: #0f172a; }
    .tk-proj-count { font-size: 12.5px; color: #64748b; }
    .tk-bar { height: 9px; background: #eef2f7; border-radius: 999px; overflow: hidden; }
    .tk-bar-fill { height: 100%; background: #1d62a8; border-radius: 999px; transition: width .3s; }
    .tk-bar-fill.tk-full { background: #16a34a; }
    .tk-proj-meta { margin-top: 6px; font-size: 11.5px; color: #94a3b8; }
    .tk-proj-meta.tk-has-over { color: #b45309; }
    .tk-done-badge { font-size: 11px; font-weight: 700; color: #166534; background: #dcfce7; border-radius: 999px; padding: 2px 11px; }
    .tk-people { margin-top: 8px; }
    .tk-people .tk-p-row { display: flex; justify-content: space-between; font-size: 13.5px; padding: 5px 4px; border-bottom: 1px solid #f6f8fb; }
    .tk-people .tk-p-n { color: #64748b; }
    #reset_filters { margin-top: 4px; }
    .tk-legend { margin-top: 16px; padding-top: 14px; border-top: 1px solid #eef2f7;
      font-size: 11.5px; color: #94a3b8; line-height: 2; }
    .tk-legend b { display: block; color: #475569; font-size: 10.5px; text-transform: uppercase;
      letter-spacing: .5px; margin-bottom: 6px; }
    .tk-k { display: inline-block; min-width: 17px; text-align: center;
      font-family: ui-monospace, Consolas, monospace; font-size: 11px; background: #f1f5f9;
      border: 1px solid #e2e8f0; border-radius: 5px; padding: 0 4px; margin-right: 6px; color: #334155; }
  "

  app_js <- "
    document.addEventListener('keydown', function(e) {
      var t = (e.target.tagName || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (document.querySelector('.modal-backdrop')) return;
      var k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      function fire(id) { e.preventDefault(); Shiny.setInputValue(id, Date.now()); }
      if (k === 'q') { fire('quit'); return; }
      if (k === 'o') { e.preventDefault(); Shiny.setInputValue('goto_tab', 'Opgaver',   {priority:'event'}); return; }
      if (k === 'p') { e.preventDefault(); Shiny.setInputValue('goto_tab', 'Projekter', {priority:'event'}); return; }
      if (k === 'r') { fire('reset_filters'); return; }
      if (k === 'f') { fire('act_done'); return; }
      if (k === 'e') { fire('act_edit'); return; }
      if (k === 'n') { fire('act_annotate'); return; }
      if (k === 'g') { fire('act_reopen'); return; }
      if (k === 'x' || k === 'Delete') { fire('act_delete'); return; }
      if (k === 'j' || k === 'ArrowDown') {
        e.preventDefault();
        Shiny.setInputValue('move_sel', 'down', {priority: 'event'}); return;
      }
      if (k === 'k' || k === 'ArrowUp') {
        e.preventDefault();
        Shiny.setInputValue('move_sel', 'up', {priority: 'event'}); return;
      }
    });
  "

  ui <- shiny::fluidPage(
    theme = theme,
    shiny::tags$head(
      shiny::tags$style(shiny::HTML(css)),
      shiny::tags$script(shiny::HTML(app_js))
    ),
    shiny::div(
      class = "tk-hero",
      shiny::div(class = "tk-hero-actions",
        shiny::actionButton("refresh", shiny::HTML("&#x21bb; Opdater"), class = "tk-ghost"),
        shiny::actionButton("quit", "Luk (Q)", class = "tk-ghost tk-ghost-quit")),
      shiny::div(class = "tk-hero-text",
        shiny::h2(shiny::HTML("&#x2713;&#xFE0E; Opgaver")),
        shiny::div(class = "tk-db", shiny::textOutput("db_label", inline = TRUE)))
    ),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 4,
        shiny::div(
          class = "tk-card",
          shiny::h4("Ny opgave"),
          shiny::textInput("n_desc", NULL, placeholder = "Hvad skal der g\u00f8res?"),
          shiny::fluidRow(
            shiny::column(6, shiny::selectizeInput("n_project", "Projekt", choices = NULL,
                                options = list(create = TRUE, createOnBlur = TRUE,
                                               persist = FALSE, placeholder = "skriv eller v\u00e6lg"))),
            shiny::column(6, shiny::selectizeInput("n_assignee", "Person", choices = NULL,
                                options = list(create = TRUE, createOnBlur = TRUE,
                                               persist = FALSE, placeholder = "skriv eller v\u00e6lg")))
          ),
          shiny::textInput("n_tags", "Tags", placeholder = "fx skrivning, vigtig"),
          shiny::fluidRow(
            shiny::column(6, shiny::selectInput("n_priority", "Prioritet",
              choices = c("Ingen" = "", "H\u00f8j" = "H", "Mellem" = "M", "Lav" = "L"))),
            shiny::column(6, suppressWarnings(shiny::dateInput("n_due", "Forfald",
              value = NA, format = "dd-mm-yyyy", language = "da", weekstart = 1,
              autoclose = TRUE)))
          ),
          shiny::selectInput("n_recur", "Gentag",
            choices = c("Nej" = "", "Dagligt" = "daily", "Ugentligt" = "weekly",
                        "Hver 14. dag" = "biweekly", "M\u00e5nedligt" = "monthly",
                        "Kvartalsvis" = "quarterly", "\u00c5rligt" = "yearly")),
          shiny::actionButton("add", "Tilf\u00f8j opgave", class = "btn-primary", width = "100%")
        ),
        shiny::div(
          class = "tk-card",
          shiny::h4("Filtre"),
          shiny::selectInput("f_status", "Status",
            choices = c("Afventer" = "pending", "F\u00e6rdige" = "completed", "Alle" = "all")),
          shiny::selectInput("f_assignee", "Person", choices = c("Alle" = "")),
          shiny::selectInput("f_project", "Projekt", choices = c("Alle" = "")),
          shiny::selectInput("f_tag", "Tag", choices = c("Alle" = "")),
          shiny::selectInput("f_sort", "Sort\u00e9r efter",
            choices = c("Vigtighed" = "urgency", "Forfald" = "due",
                        "Oprettet" = "entry", "Projekt" = "project")),
          shiny::actionButton("reset_filters", "Nulstil filtre (R)",
                              class = "btn-default", width = "100%"),
          shiny::div(class = "tk-legend",
            shiny::HTML(paste(
              "<b>Genveje</b>",
              "<span class='tk-k'>j</span><span class='tk-k'>k</span> v\u00e6lg",
              "<span class='tk-k'>f</span> f\u00e6rdig",
              "<span class='tk-k'>e</span> rediger",
              "<span class='tk-k'>n</span> note",
              "<span class='tk-k'>g</span> gen\u00e5bn",
              "<span class='tk-k'>x</span> slet",
              "<span class='tk-k'>r</span> nulstil",
              "<span class='tk-k'>o</span> opgaver",
              "<span class='tk-k'>p</span> projekter",
              "<span class='tk-k'>q</span> luk", sep = "<br>")))
        )
      ),
      shiny::mainPanel(
        width = 8,
        shiny::tabsetPanel(
          id = "main_tabs", type = "pills",
          shiny::tabPanel(
            "Opgaver",
            shiny::div(style = "margin-top: 16px;", shiny::uiOutput("stats")),
            shiny::div(class = "tk-card", shiny::uiOutput("tasklist")),
            shiny::uiOutput("detail")
          ),
          shiny::tabPanel(
            "Projekter",
            shiny::div(style = "margin-top: 16px;", class = "tk-card",
                       shiny::uiOutput("projects"))
          )
        )
      )
    )
  )

  shiny::runApp(shiny::shinyApp(ui, .task_app_server(start_db)), quiet = TRUE)
}

# The server is factored out so it can be driven with shiny::testServer
# without launching a browser.
.task_app_server <- function(start_db) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  function(input, output, session) {
    db_path <- shiny::reactiveVal(start_db)
    refresh <- shiny::reactiveVal(0)
    form_ver <- shiny::reactiveVal(0)
    selected <- shiny::reactiveVal(NULL)
    # Isolate the read so the bumps never make their caller depend on the
    # value -- otherwise the timer observe below would loop on itself.
    bump  <- function() refresh(shiny::isolate(refresh()) + 1)
    # form_ver only changes on the user's own actions, so the timer never
    # rebuilds the form pickers and never resets what is being typed.
    fbump <- function() form_ver(shiny::isolate(form_ver()) + 1)

    # ISO date (yyyy-mm-dd) -> Danish dd-mm-yyyy for display.
    ddmm <- function(iso) {
      if (length(iso) == 0 || is.na(iso) || !nzchar(iso)) return("")
      format(as.Date(iso), "%d-%m-%Y")
    }

    shiny::observeEvent(input$quit, shiny::stopApp())

    shiny::observeEvent(input$goto_tab,
      shiny::updateTabsetPanel(session, "main_tabs", selected = input$goto_tab))

    shiny::observeEvent(input$reset_filters, {
      shiny::updateSelectInput(session, "f_status",   selected = "pending")
      shiny::updateSelectInput(session, "f_assignee", selected = "")
      shiny::updateSelectInput(session, "f_project",  selected = "")
      shiny::updateSelectInput(session, "f_tag",      selected = "")
      shiny::updateSelectInput(session, "f_sort",     selected = "urgency")
    })

    # j/k (or arrows) move the selection through the current list.
    shiny::observeEvent(input$move_sel, {
      ids <- tasks()$id
      if (length(ids) == 0) return()
      cur <- selected()
      i <- if (is.null(cur)) NA_integer_ else match(cur, ids)
      ni <- if (is.na(i)) 1L
            else if (input$move_sel == "down") min(i + 1L, length(ids))
            else max(i - 1L, 1L)
      selected(ids[ni])
    })

    # Re-read the list/projects on a timer so other people's changes show
    # up. This deliberately does not touch the form pickers.
    shiny::observe({
      shiny::invalidateLater(10000, session)
      bump()
    })

    output$db_label <- shiny::renderText(paste("Database:", db_path()))

    tasks <- shiny::reactive({
      refresh()
      task_list(
        db_path(),
        status   = input$f_status %||% "pending",
        project  = if (shiny::isTruthy(input$f_project)) input$f_project else NULL,
        assignee = if (shiny::isTruthy(input$f_assignee)) input$f_assignee else NULL,
        tag      = if (shiny::isTruthy(input$f_tag)) input$f_tag else NULL,
        sort     = input$f_sort %||% "urgency"
      )
    })

    all_tasks <- shiny::reactive({
      refresh()
      task_list(db_path(), status = "pending")
    })

    # Keep the project/person/tag pickers in sync. Driven by form_ver
    # (your own actions + startup), NOT the timer, so a refresh never
    # clears a half-typed entry.
    shiny::observe({
      form_ver()
      everyone <- task_list(db_path(), status = "all")
      pr <- sort(unique(everyone$project[!is.na(everyone$project)]))
      # Client-side selectize (no server = TRUE) so a freshly typed,
      # newly-created option registers reliably as the input value.
      shiny::updateSelectizeInput(session, "n_project", choices = pr,
                                  selected = shiny::isolate(input$n_project))
      shiny::updateSelectInput(session, "f_project", choices = c("Alle" = "", pr),
                               selected = shiny::isolate(input$f_project))
      who <- sort(unique(everyone$assignee[!is.na(everyone$assignee) & everyone$assignee != ""]))
      shiny::updateSelectizeInput(session, "n_assignee", choices = who,
                                  selected = shiny::isolate(input$n_assignee))
      shiny::updateSelectInput(session, "f_assignee", choices = c("Alle" = "", who),
                               selected = shiny::isolate(input$f_assignee))
      tg <- everyone$tags
      tg <- sort(unique(unlist(strsplit(tg[nzchar(tg)], ",", fixed = TRUE))))
      shiny::updateSelectInput(session, "f_tag", choices = c("Alle" = "", tg),
                               selected = shiny::isolate(input$f_tag))
    })

    shiny::observeEvent(input$add, {
      shiny::req(shiny::isTruthy(input$n_desc))
      tags <- trimws(strsplit(input$n_tags %||% "", "[,;[:space:]]+")[[1]])
      tags <- tags[nzchar(tags)]
      ok <- tryCatch({
        task_add(
          db_path(), input$n_desc,
          project  = if (shiny::isTruthy(input$n_project)) input$n_project else NULL,
          assignee = if (shiny::isTruthy(input$n_assignee)) input$n_assignee else NULL,
          tags     = tags,
          priority = if (shiny::isTruthy(input$n_priority)) input$n_priority else NULL,
          due      = if (shiny::isTruthy(input$n_due)) input$n_due else NULL,
          recur    = if (shiny::isTruthy(input$n_recur)) input$n_recur else NULL
        )
        TRUE
      }, error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); FALSE })
      if (ok) {
        shiny::updateTextInput(session, "n_desc", value = "")
        shiny::updateTextInput(session, "n_tags", value = "")
        bump(); fbump()
        shiny::showNotification("Opgave tilf\u00f8jet.", duration = 2, type = "message")
      }
    })

    shiny::observeEvent(input$refresh, bump())
    shiny::observeEvent(input$pick_task, selected(as.integer(input$pick_task)))

    output$stats <- shiny::renderUI({
      pend <- all_tasks()
      over <- sum(!is.na(pend$due) & as.Date(pend$due) < Sys.Date())
      nproj <- nrow(task_projects(db_path()))
      stat <- function(n, lab, cls = "") shiny::div(class = paste("tk-stat", cls),
        shiny::div(class = "tk-n", n), shiny::div(class = "tk-l", lab))
      shiny::div(class = "tk-stats",
        stat(nrow(pend), "afventer"),
        stat(over, "forfaldne", if (over > 0) "tk-over" else ""),
        stat(nproj, "projekter"))
    })

    output$tasklist <- shiny::renderUI({
      df <- tasks()
      if (nrow(df) == 0)
        return(shiny::div(class = "tk-empty",
          shiny::div(class = "tk-empty-ico", "\U0001F4ED"),
          shiny::p(shiny::strong("Ingen opgaver her")),
          shiny::p(class = "tk-l", "Tilf\u00f8j en opgave i venstre side.")))
      sel <- selected()
      rows <- lapply(seq_len(nrow(df)), function(i) {
        t <- df[i, ]
        due_cls <- ""; due_txt <- NULL
        if (!is.na(t$due) && nzchar(t$due)) {
          dd <- as.Date(t$due); dleft <- as.numeric(dd - Sys.Date())
          due_cls <- if (dleft < 0) "tk-over" else if (dleft <= 3) "tk-soon" else ""
          due_txt <- ddmm(t$due)
        }
        tagchips <- if (nzchar(t$tags))
          lapply(strsplit(t$tags, ",", fixed = TRUE)[[1]],
                 function(x) shiny::span(class = "tk-chip tk-tag", x))
        shiny::div(
          class = paste("tk-row", if (!is.null(sel) && sel == t$id) "selected"),
          onclick = sprintf("Shiny.setInputValue('pick_task','%s',{priority:'event'})", t$id),
          shiny::div(class = "tk-urg", formatC(t$urgency, format = "f", digits = 1)),
          if (!is.na(t$priority))
            shiny::span(class = paste0("tk-pri tk-pri-", t$priority), t$priority),
          shiny::div(class = "tk-main",
            shiny::div(class = "tk-desc", t$description),
            shiny::div(class = "tk-meta",
              if (!is.na(t$project)) shiny::span(class = "tk-chip tk-proj", t$project),
              if (!is.na(t$assignee) && nzchar(t$assignee))
                shiny::span(class = "tk-chip tk-person", paste0("\U0001F464 ", t$assignee)),
              tagchips,
              if (t$annotations > 0) shiny::span(class = "tk-ann", paste0("\U0001F4DD ", t$annotations)))),
          if (isTRUE(t$blocked)) shiny::span(class = "tk-blocked", "blokeret"),
          if (!is.null(due_txt)) shiny::span(class = paste("tk-due", due_cls), due_txt)
        )
      })
      shiny::div(class = "tk-rows", rows)
    })

    sel_task <- shiny::reactive({
      refresh()                       # re-read after notes / edits / status changes
      id <- selected()
      if (is.null(id)) return(NULL)
      df <- task_list(db_path(), status = "all")
      row <- df[df$id == id, ]
      if (nrow(row) == 0) NULL else row
    })

    output$detail <- shiny::renderUI({
      t <- sel_task()
      if (is.null(t)) return(NULL)
      drow <- function(k, v) shiny::div(class = "tk-d-row",
        shiny::span(class = "tk-d-k", k), shiny::span(v))
      ann <- task_annotations(db_path(), t$id)
      shiny::div(
        class = "tk-card tk-detail",
        shiny::h4(t$description),
        drow("Status", t$status),
        if (!is.na(t$project)) drow("Projekt", t$project),
        if (!is.na(t$assignee) && nzchar(t$assignee)) drow("Person", t$assignee),
        if (!is.na(t$priority)) drow("Prioritet", t$priority),
        if (!is.na(t$due)) drow("Forfald", ddmm(t$due)),
        if (nzchar(t$tags)) drow("Tags", t$tags),
        if (!is.na(t$recur)) drow("Gentag", t$recur),
        drow("Vigtighed", formatC(t$urgency, format = "f", digits = 1)),
        if (nrow(ann) > 0) shiny::div(style = "margin-top:10px;",
          lapply(seq_len(nrow(ann)), function(i) shiny::div(class = "tk-note",
            shiny::div(class = "tk-note-t", substr(ann$entry[i], 1, 16)),
            ann$text[i]))),
        shiny::div(class = "tk-actions",
          if (t$status == "pending")
            shiny::actionButton("act_done", "F\u00e6rdig (F)", class = "btn-primary"),
          if (t$status != "pending")
            shiny::actionButton("act_reopen", "Gen\u00e5bn (G)", class = "btn-primary"),
          if (t$status == "pending")
            shiny::actionButton("act_edit", "Rediger (E)", class = "btn-default"),
          shiny::actionButton("act_annotate", "Tilf\u00f8j note (N)", class = "btn-default"),
          if (t$status == "pending")
            shiny::actionButton("act_delete", "Slet (X)", class = "btn-default"))
      )
    })

    output$projects <- shiny::renderUI({
      refresh()
      pr <- task_projects(db_path())
      ppl <- task_people(db_path())
      if (nrow(pr) == 0)
        return(shiny::div(class = "tk-empty",
          shiny::div(class = "tk-empty-ico", "\U0001F4CA"),
          shiny::p(shiny::strong("Ingen projekter endnu")),
          shiny::p(class = "tk-l", "Tilf\u00f8j opgaver med et projekt for at se overblikket.")))
      rows <- lapply(seq_len(nrow(pr)), function(i) {
        p <- pr[i, ]
        done <- p$pending == 0 && p$total > 0
        meta <- paste(c(
          paste0("Oprettet ", ddmm(p$created)),
          paste0("Sidst aktiv ", ddmm(p$last_activity)),
          if (p$overdue > 0) paste0(p$overdue, " forfaldne")
        ), collapse = "  \u00b7  ")
        shiny::div(
          class = "tk-proj-row",
          shiny::div(class = "tk-proj-head",
            shiny::span(class = "tk-proj-name", p$project),
            if (done) shiny::span(class = "tk-done-badge", "Klaret")
            else shiny::span(class = "tk-proj-count",
                             paste0(p$completed, " af ", p$total, " klaret \u00b7 ", p$pending, " mangler"))),
          shiny::div(class = "tk-bar",
            shiny::div(class = paste("tk-bar-fill", if (done) "tk-full"),
                       style = sprintf("width:%d%%;", p$pct_done))),
          shiny::div(class = paste("tk-proj-meta", if (p$overdue > 0) "tk-has-over"), meta))
      })
      people <- if (nrow(ppl) > 0) shiny::tagList(
        shiny::h4(style = "margin-top: 18px;", "Personer"),
        shiny::div(class = "tk-people",
          lapply(seq_len(nrow(ppl)), function(i) shiny::div(class = "tk-p-row",
            shiny::span(paste0("\U0001F464 ", ppl$assignee[i])),
            shiny::span(class = "tk-p-n", paste(ppl$pending[i], "afventer"))))))
      shiny::tagList(shiny::h4("Projektoverblik"), rows, people)
    })

    shiny::observeEvent(input$act_done, {
      shiny::req(selected()); task_done(db_path(), selected()); bump()
      shiny::showNotification("Opgave fuldf\u00f8rt.", duration = 2)
    })
    shiny::observeEvent(input$act_reopen, {
      shiny::req(selected()); task_reopen(db_path(), selected()); bump()
      shiny::showNotification("Opgave gen\u00e5bnet.", duration = 2)
    })
    shiny::observeEvent(input$act_delete, {
      shiny::req(selected()); task_delete(db_path(), selected()); selected(NULL); bump(); fbump()
      shiny::showNotification("Opgave slettet.", duration = 2)
    })
    shiny::observeEvent(input$act_annotate, {
      shiny::req(selected())
      shiny::showModal(shiny::modalDialog(
        title = "Tilf\u00f8j note",
        shiny::textAreaInput("ann_text", NULL, placeholder = "Skriv en note ...", width = "100%"),
        footer = shiny::tagList(shiny::modalButton("Annuller"),
                                shiny::actionButton("ann_ok", "Gem", class = "btn-primary")),
        easyClose = TRUE))
    })
    shiny::observeEvent(input$ann_ok, {
      shiny::req(selected(), shiny::isTruthy(input$ann_text))
      task_annotate(db_path(), selected(), input$ann_text)
      shiny::removeModal(); bump()
      shiny::showNotification("Note tilf\u00f8jet.", duration = 2)
    })
    shiny::observeEvent(input$act_edit, {
      t <- sel_task(); shiny::req(t)
      shiny::showModal(shiny::modalDialog(
        title = "Rediger opgave",
        shiny::textInput("e_desc", "Beskrivelse", value = t$description),
        shiny::textInput("e_project", "Projekt", value = if (is.na(t$project)) "" else t$project),
        shiny::textInput("e_assignee", "Person", value = if (is.na(t$assignee)) "" else t$assignee),
        shiny::textInput("e_tags", "Tags", value = t$tags),
        shiny::selectInput("e_priority", "Prioritet",
          choices = c("Ingen" = "", "H\u00f8j" = "H", "Mellem" = "M", "Lav" = "L"),
          selected = if (is.na(t$priority)) "" else t$priority),
        suppressWarnings(shiny::dateInput("e_due", "Forfald",
          value = if (is.na(t$due)) NA else as.Date(t$due),
          format = "dd-mm-yyyy", language = "da", weekstart = 1, autoclose = TRUE)),
        footer = shiny::tagList(shiny::modalButton("Annuller"),
                                shiny::actionButton("edit_ok", "Gem", class = "btn-primary")),
        easyClose = TRUE))
    })
    shiny::observeEvent(input$edit_ok, {
      shiny::req(selected())
      tags <- trimws(strsplit(input$e_tags %||% "", "[,;[:space:]]+")[[1]])
      ok <- tryCatch({
        task_modify(db_path(), selected(),
          description = input$e_desc,
          project  = if (shiny::isTruthy(input$e_project)) input$e_project else "",
          assignee = if (shiny::isTruthy(input$e_assignee)) input$e_assignee else "",
          tags     = tags[nzchar(tags)],
          priority = if (shiny::isTruthy(input$e_priority)) input$e_priority else NULL,
          due      = if (shiny::isTruthy(input$e_due)) input$e_due else NULL)
        TRUE
      }, error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); FALSE })
      if (ok) { shiny::removeModal(); bump(); fbump() }
    })
  }
}
