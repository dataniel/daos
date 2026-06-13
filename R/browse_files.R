# A yazi-inspired filesystem browser, built on the same three-column
# navigation as statbank_app() but over local directories instead of a
# PXWeb tree. Listing is plain base R, so there is no network and no new
# dependency. Pressing Q returns the marked paths (or the cursor path) to
# R as a string or a character vector.

# List one directory as a tibble: directories first, then files, each
# alphabetical. Returns full paths with forward slashes. Permission or
# other errors yield an empty listing rather than aborting the app.
.bf_list <- function(dir) {
  empty <- tibble::tibble(name = character(), type = character(),
                          full = character(), size = double(),
                          mtime = as.POSIXct(character()))
  entries <- tryCatch(
    list.files(dir, all.files = FALSE, full.names = TRUE, no.. = TRUE),
    error = function(e) character()
  )
  if (length(entries) == 0) return(empty)

  info  <- file.info(entries)
  is_dir <- !is.na(info$isdir) & info$isdir
  full  <- normalizePath(entries, winslash = "/", mustWork = FALSE)
  out <- tibble::tibble(
    name  = basename(entries),
    type  = ifelse(is_dir, "d", "f"),
    full  = full,
    size  = info$size,
    mtime = info$mtime
  )
  out[order(out$type != "d", tolower(out$name)), ]
}

# Filesystem roots: existing drive letters on Windows, "/" elsewhere.
# This is the level above every path, used as the drive chooser.
.bf_roots <- function() {
  if (.Platform$OS.type == "windows") {
    drives <- paste0(LETTERS, ":/")
    drives[vapply(drives, dir.exists, logical(1))]
  } else {
    "/"
  }
}

# TRUE when `path` is a filesystem root (its own parent).
.bf_is_root <- function(path) {
  normalizePath(dirname(path), winslash = "/", mustWork = FALSE) ==
    normalizePath(path, winslash = "/", mustWork = FALSE)
}

# Render one or more paths as an R expression: a single path becomes a
# quoted string, several become c("a", "b"). Backslashes are flipped to
# forward slashes so the result drops straight into R code.
.bf_rstring <- function(paths) {
  if (length(paths) == 0) return("")
  paths <- gsub("\\\\", "/", paths)
  quoted <- paste0('"', paths, '"')
  if (length(quoted) == 1) return(quoted)
  paste0("c(", paste(quoted, collapse = ", "), ")")
}

# Human-readable file size.
.bf_size <- function(bytes) {
  if (is.na(bytes)) return("")
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- if (bytes <= 0) 1L else min(length(units), floor(log(bytes, 1024)) + 1L)
  v <- bytes / 1024^(i - 1)
  paste0(if (i == 1) round(v) else sprintf("%.1f", v), " ", units[i])
}

#' Browse the filesystem and copy paths to R
#'
#' Launches a Shiny app that walks the local filesystem in a three-column,
#' yazi-style browser: parent directory, current directory, and a live
#' preview of the item under the cursor. Navigate with `h`/`j`/`k`/`l` or
#' the arrow keys. The point is to grab paths without typing them: mark
#' one or more files or folders and copy them, or return them to R.
#'
#' - `Space` marks/unmarks the item under the cursor (files or folders).
#' - `y` (or the button) copies the marked paths as an R expression -- a
#'   quoted string for one, a `c("a", "b")` vector for several -- with
#'   forward slashes, ready to paste into a script.
#' - `o` (or the button) opens the item under the cursor in the system
#'   file explorer via [daos::open_in_explorer()] (a folder opens, a file
#'   is revealed in its folder).
#' - `l`/Enter enters a folder or copies a file's path; `h` goes up a
#'   level, all the way to the drive chooser at the root.
#' - `Q` closes the app and returns the marked paths (or, if none are
#'   marked, the path under the cursor).
#'
#' @param path Directory to start in. Default: the working directory.
#'
#' @return A character vector of the marked paths, invisibly -- a single
#'   string when one path is marked or the cursor path is used, a vector
#'   when several are marked. `character(0)` if nothing is resolved.
#'
#' @examples
#' \dontrun{
#' p <- browse_files()          # navigate, mark, press Q
#' files <- browse_files("data") # start in data/, return marked files
#' }
#'
#' @seealso [daos::open_in_explorer()]
#'
#' @importFrom cli cli_abort
#' @export
browse_files <- function(path = getwd()) {
  for (pkg in c("shiny")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required for the app. Install with {.code install.packages('{pkg}')}.")
  }
  if (!dir.exists(path))
    cli::cli_abort("Directory {.path {path}} does not exist.")
  start_path <- normalizePath(path, winslash = "/", mustWork = TRUE)

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
    .bf-hero {
      margin: -15px -15px 18px -15px; padding: 22px 34px 18px;
      background: linear-gradient(135deg, #0c3a63 0%, #1d62a8 100%); color: #fff;
    }
    .bf-hero h2 { font-weight: 700; letter-spacing: -0.3px; margin: 0 0 4px; color: #fff; font-size: 22px; }
    .bf-sub { color: #c7dbef; margin: 0; font-size: 14px; }
    .bf-tag {
      float: right; background: rgba(255,255,255,.14); color: #e6eef7;
      border-radius: 999px; padding: 4px 14px; font-size: 12.5px; letter-spacing: .4px;
    }
    .bf-card {
      background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
      box-shadow: 0 1px 2px rgba(15,23,42,.05), 0 4px 16px rgba(15,23,42,.05);
      padding: 20px;
    }
    .bf-crumbs { font-size: 13.5px; color: #475569; margin: 4px 0 12px; word-break: break-all; }
    .bf-crumbs a { cursor: pointer; color: #1d62a8; text-decoration: none; font-weight: 600; }
    .bf-crumbs a:hover { text-decoration: underline; }
    .bf-crumbs .bf-sep { color: #94a3b8; margin: 0 5px; }
    .bf-browser { display: flex; gap: 14px; }
    .bf-col {
      flex: 1; min-width: 0; max-height: 60vh; overflow-y: auto;
      border: 1px solid #e2e8f0; border-radius: 10px; background: #fafcfe; padding: 6px;
    }
    .bf-col-preview { background: #f8fafc; }
    .bf-colhead {
      font-size: 11.5px; font-weight: 700; letter-spacing: .5px;
      text-transform: uppercase; color: #94a3b8; padding: 6px 10px 4px;
    }
    .bf-col-preview .bf-colhead { color: #b6c2d1; }
    .bf-item {
      display: block; padding: 7px 10px; border-radius: 8px; cursor: pointer;
      font-size: 13.5px; color: #1e293b; line-height: 1.35; white-space: nowrap;
      overflow: hidden; text-overflow: ellipsis;
    }
    .bf-item:hover { background: #e8f0fa; }
    .bf-item.cursor { outline: 2px solid #1d62a8; outline-offset: -2px; background: #e8f0fa; }
    .bf-item.active { background: #1d62a8; color: #fff; }
    .bf-item.marked { background: #dcfce7; }
    .bf-item.marked.cursor { background: #bbf7d0; }
    .bf-ico { margin-right: 8px; }
    .bf-ico-d { color: #1d62a8; }
    .bf-ico-f { color: #94a3b8; }
    .bf-check { color: #16a34a; float: right; margin-left: 8px; font-weight: 700; }
    .bf-item.sb-faux, .bf-faux { background: #eef4fb; color: #1d62a8; font-weight: 600; cursor: default; }
    .bf-faux:hover { background: #eef4fb; }
    .bf-preview-ro { cursor: default; color: #475569; }
    .bf-preview-ro:hover { background: transparent; }
    .bf-fileinfo { padding: 10px 8px; }
    .bf-fileinfo strong { color: #0f3b66; word-break: break-all; }
    .bf-fileinfo p { color: #64748b; font-size: 12.5px; margin: 6px 0 2px; }
    .bf-hint { color: #64748b; font-size: 12.5px; }
    .bf-bar {
      display: flex; align-items: center; gap: 10px; margin-top: 14px; flex-wrap: wrap;
    }
    .bf-bar .btn { border-radius: 8px; font-weight: 600; }
    .bf-bar .btn-primary { background: #1d62a8; border-color: #1d62a8; }
    .bf-count {
      color: #475569; font-size: 13px; font-weight: 600; background: #f1f5f9;
      border-radius: 999px; padding: 4px 12px;
    }
    .bf-selbox {
      margin-left: auto; flex: 1 1 320px; min-width: 200px;
    }
    .bf-selbox pre {
      background: #0f172a; color: #e2e8f0; border-radius: 8px; padding: 10px 12px;
      font-size: 12.5px; margin: 0; white-space: pre-wrap; word-break: break-all;
    }
  "

  app_js <- "
    document.addEventListener('keydown', function(e) {
      var t = (e.target.tagName || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (e.key === 'q' || e.key === 'Q') { Shiny.setInputValue('quit', Date.now()); return; }
      if (e.key === 'Enter' && (t === 'button' || t === 'a')) return;
      if (document.querySelector('.modal-backdrop')) return;

      var key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      if (key === 'y') { e.preventDefault(); Shiny.setInputValue('do_copy', Date.now()); return; }
      if (key === 'o') { e.preventDefault(); Shiny.setInputValue('do_open', Date.now()); return; }

      var items = document.querySelectorAll('.bf-col-current .bf-item');
      if (items.length === 0) return;

      var down = (key === 'j' || key === 'ArrowDown');
      var up   = (key === 'k' || key === 'ArrowUp');
      var open = (key === 'l' || key === 'ArrowRight' || key === 'Enter');
      var back = (key === 'h' || key === 'ArrowLeft');
      var mark = (key === ' ' || e.code === 'Space');
      if (!(down || up || open || back || mark)) return;
      e.preventDefault();

      var cur = -1;
      for (var i = 0; i < items.length; i++) {
        if (items[i].classList.contains('cursor')) { cur = i; break; }
      }
      function sendCursor(el) {
        if (!el) return;
        Shiny.setInputValue('bf_cursor', {
          full: el.getAttribute('data-full'),
          type: el.getAttribute('data-type'), n: Date.now()
        });
      }
      if (down || up) {
        var nxt;
        if (cur === -1) { nxt = down ? 0 : items.length - 1; }
        else {
          nxt = down ? Math.min(cur + 1, items.length - 1) : Math.max(cur - 1, 0);
          items[cur].classList.remove('cursor');
        }
        items[nxt].classList.add('cursor');
        items[nxt].scrollIntoView({block: 'nearest'});
        sendCursor(items[nxt]);
      } else if (mark) {
        if (cur >= 0) Shiny.setInputValue('bf_toggle', {
          full: items[cur].getAttribute('data-full'), n: Date.now()
        });
      } else if (open) {
        if (cur >= 0) items[cur].click();
      } else if (back) {
        var crumbs = document.querySelectorAll('.bf-crumbs a');
        if (crumbs.length >= 2) crumbs[crumbs.length - 2].click();
      }
    });
    function bfFallbackCopy(txt) {
      var ta = document.createElement('textarea');
      ta.value = txt; ta.style.position = 'fixed'; ta.style.opacity = '0';
      document.body.appendChild(ta); ta.focus(); ta.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
    }
    Shiny.addCustomMessageHandler('bf_clip', function(txt) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(function(){}, function(){ bfFallbackCopy(txt); });
      } else { bfFallbackCopy(txt); }
    });
  "

  ui <- shiny::fluidPage(
    theme = theme,
    shiny::tags$head(
      shiny::tags$style(shiny::HTML(css)),
      shiny::tags$script(shiny::HTML(app_js))
    ),
    shiny::div(
      class = "bf-hero",
      shiny::span(class = "bf-tag", "daos"),
      shiny::h2("Filstier"),
      shiny::p(class = "bf-sub",
               "Bladr med tastaturet, mark\u00e9r filer eller mapper, og tag stierne med ind i R.")
    ),
    shiny::div(
      class = "bf-card",
      shiny::div(class = "bf-crumbs", shiny::uiOutput("crumbs", inline = TRUE)),
      shiny::uiOutput("browser"),
      shiny::div(
        class = "bf-bar",
        shiny::actionButton("do_copy", "Kopier R-sti (y)", class = "btn-primary"),
        shiny::actionButton("do_open", "\u00c5bn i stifinder (o)", class = "btn-default"),
        shiny::span(class = "bf-count", shiny::textOutput("count", inline = TRUE)),
        shiny::div(class = "bf-selbox", shiny::tags$pre(shiny::textOutput("rstring")))
      ),
      shiny::helpText(
        "Tastatur: j/k flytter, l/Enter \u00e5bner mappe, h g\u00e5r op, mellemrum",
        " mark\u00e9rer, y kopierer, o \u00e5bner i stifinder, Q lukker og returnerer stierne.")
    )
  )

  server <- function(input, output, session) {
    cur_path <- shiny::reactiveVal(start_path)
    cursor   <- shiny::reactiveVal(NULL)
    marked   <- shiny::reactiveVal(character())

    cache <- new.env(parent = emptyenv())
    listing <- function(dir) {
      key <- dir
      if (is.null(cache[[key]])) cache[[key]] <- .bf_list(dir)
      cache[[key]]
    }

    # Target set: the marked paths, or the cursor path when nothing is
    # marked. Drives the copy action and the return value.
    target <- shiny::reactive({
      m <- marked()
      if (length(m) > 0) return(m)
      cu <- cursor()
      if (!is.null(cu)) cu$full else character()
    })

    shiny::observeEvent(input$quit, {
      shiny::stopApp(invisible(target()))
    })

    # Reset the cursor to the first row whenever the directory changes.
    shiny::observe({
      nodes <- listing(cur_path())
      if (nrow(nodes) > 0) {
        cursor(list(full = nodes$full[1], type = nodes$type[1]))
      } else {
        cursor(NULL)
      }
    })
    shiny::observeEvent(input$bf_cursor, {
      cursor(list(full = input$bf_cursor$full, type = input$bf_cursor$type))
    })

    shiny::observeEvent(input$bf_toggle, {
      p <- input$bf_toggle$full
      m <- marked()
      if (p %in% m) marked(setdiff(m, p)) else marked(c(m, p))
    })

    shiny::observeEvent(input$go, cur_path(input$go))
    shiny::observeEvent(input$pick_file, {
      cursor(list(full = input$pick_file, type = "f"))
    })

    # Clicking a folder navigates; clicking a file selects it (so it can
    # be copied or opened). Both carry data attributes for the keyboard
    # handler.
    item_row <- function(row, cursor_on = FALSE) {
      marked_now <- row$full %in% marked()
      cls <- c("bf-item", paste0("bf-row-", row$type),
               if (cursor_on) "cursor", if (marked_now) "marked")
      onclick <- if (row$type == "d") {
        sprintf("Shiny.setInputValue('go', '%s', {priority:'event'})", row$full)
      } else {
        sprintf("Shiny.setInputValue('pick_file', '%s', {priority:'event'})", row$full)
      }
      shiny::div(
        class = paste(cls, collapse = " "),
        `data-full` = row$full, `data-type` = row$type, onclick = onclick,
        shiny::span(class = paste0("bf-ico bf-ico-", row$type),
                    if (row$type == "d") "\U0001F4C1" else "\U0001F4C4"),
        row$name,
        if (marked_now) shiny::span(class = "bf-check", "\u2713")
      )
    }

    drive_row <- function(d, active = FALSE) {
      shiny::div(
        class = paste(c("bf-item", if (active) "active"), collapse = " "),
        `data-full` = d, `data-type` = "d",
        onclick = sprintf("Shiny.setInputValue('go', '%s', {priority:'event'})", d),
        shiny::span(class = "bf-ico bf-ico-d", "\U0001F4BE"), d
      )
    }

    output$crumbs <- shiny::renderUI({
      path <- cur_path()
      parts <- strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1]]
      parts <- parts[nzchar(parts)]
      crumbs <- list()
      acc <- if (.Platform$OS.type != "windows") "/" else ""
      for (i in seq_along(parts)) {
        acc <- if (i == 1 && .Platform$OS.type == "windows") paste0(parts[i], "/")
               else if (acc == "/") paste0("/", parts[i])
               else paste0(acc, if (!endsWith(acc, "/")) "/", parts[i])
        target_path <- acc
        crumbs <- c(crumbs, list(
          if (i > 1) shiny::span(class = "bf-sep", "/"),
          shiny::tags$a(onclick = sprintf(
            "Shiny.setInputValue('go', '%s', {priority:'event'})", target_path),
            parts[i])
        ))
      }
      crumbs
    })

    output$browser <- shiny::renderUI({
      path <- cur_path()
      nodes <- listing(path)

      cur_col <- shiny::div(
        class = "bf-col bf-col-current",
        shiny::div(class = "bf-colhead", basename(path)),
        if (nrow(nodes) == 0) shiny::p(class = "bf-hint", style = "padding:8px;", "Tom mappe.")
        else lapply(seq_len(nrow(nodes)), function(i) item_row(nodes[i, ], cursor_on = i == 1))
      )

      # Left column: parent directory, or the drive chooser at the root.
      parent_col <- if (.bf_is_root(path)) {
        shiny::div(
          class = "bf-col",
          shiny::div(class = "bf-colhead", "Drev"),
          lapply(.bf_roots(), function(d) drive_row(d, active = startsWith(path, d)))
        )
      } else {
        ppath <- normalizePath(dirname(path), winslash = "/", mustWork = FALSE)
        pnodes <- listing(ppath)
        shiny::div(
          class = "bf-col",
          shiny::div(class = "bf-colhead", "Niveau op"),
          lapply(seq_len(nrow(pnodes)), function(i) {
            row <- pnodes[i, ]
            active <- row$type == "d" && normalizePath(row$full, winslash = "/", mustWork = FALSE) == path
            cls <- c("bf-item", if (active) "active")
            shiny::div(
              class = paste(cls, collapse = " "),
              onclick = if (row$type == "d")
                sprintf("Shiny.setInputValue('go', '%s', {priority:'event'})", row$full),
              shiny::span(class = paste0("bf-ico bf-ico-", row$type),
                          if (row$type == "d") "\U0001F4C1" else "\U0001F4C4"),
              row$name
            )
          })
        )
      }

      preview_col <- shiny::div(
        class = "bf-col bf-col-preview",
        shiny::div(class = "bf-colhead", "Forh\u00e5ndsvisning"),
        shiny::uiOutput("preview")
      )

      shiny::div(class = "bf-browser", parent_col, cur_col, preview_col)
    })

    output$preview <- shiny::renderUI({
      cu <- cursor()
      if (is.null(cu)) return(NULL)
      if (identical(cu$type, "d")) {
        kids <- listing(cu$full)
        if (nrow(kids) == 0) return(shiny::p(class = "bf-hint", style = "padding:8px;", "Tom mappe."))
        lapply(seq_len(nrow(kids)), function(i) {
          row <- kids[i, ]
          shiny::div(
            class = "bf-item bf-preview-ro",
            shiny::span(class = paste0("bf-ico bf-ico-", row$type),
                        if (row$type == "d") "\U0001F4C1" else "\U0001F4C4"),
            row$name
          )
        })
      } else {
        info <- file.info(cu$full)
        ext  <- tools::file_ext(cu$full)
        shiny::div(
          class = "bf-fileinfo",
          shiny::p(shiny::span(class = "bf-ico bf-ico-f", "\U0001F4C4"),
                   shiny::strong(basename(cu$full))),
          shiny::p(paste0("St\u00f8rrelse: ", .bf_size(info$size))),
          if (!is.na(info$mtime)) shiny::p(paste0("\u00c6ndret: ", format(info$mtime, "%Y-%m-%d %H:%M"))),
          if (nzchar(ext)) shiny::p(paste0("Type: .", ext)),
          shiny::p(class = "bf-hint", "Mellemrum mark\u00e9rer \u00b7 y kopierer \u00b7 o \u00e5bner i stifinder.")
        )
      }
    })

    output$count <- shiny::renderText({
      n <- length(marked())
      if (n == 0) "ingen markeret" else paste(n, if (n == 1) "markeret" else "markerede")
    })

    output$rstring <- shiny::renderText({
      tg <- target()
      if (length(tg) == 0) "(intet valgt)" else .bf_rstring(tg)
    })

    shiny::observeEvent(input$do_copy, {
      tg <- target()
      if (length(tg) > 0) {
        session$sendCustomMessage("bf_clip", .bf_rstring(tg))
        shiny::showNotification("Kopieret til udklipsholderen.", duration = 2, type = "message")
      }
    })

    shiny::observeEvent(input$do_open, {
      cu <- cursor()
      if (!is.null(cu)) {
        tryCatch(open_in_explorer(cu$full),
                 error = function(e) shiny::showNotification(conditionMessage(e),
                                                             duration = 4, type = "error"))
      }
    })
  }

  invisible(shiny::runApp(shiny::shinyApp(ui, server), quiet = TRUE))
}
