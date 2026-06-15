# A yazi-inspired filesystem browser, built on the same three-column
# navigation as statbank_app() but over local directories instead of a
# PXWeb tree. Listing is plain base R, so there is no network and no new
# dependency. Enter inserts the marked paths into the active RStudio
# document; Q closes the app and returns them to R.

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

  # extra_cols = FALSE skips owner/group resolution (which warns "cannot
  # resolve owner" on protected entries), and dir.exists() classifies
  # directories without needing read access -- so listing a drive root
  # with locked folders (Config.Msi, System Volume Information, ...)
  # stays quiet and correct.
  info  <- suppressWarnings(file.info(entries, extra_cols = FALSE))
  is_dir <- dir.exists(entries)
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
# quoted string, several become a c() with one path per line (like
# addin_text_to_vector). Backslashes are flipped to forward slashes so
# the result drops straight into R code.
.bf_rstring <- function(paths) {
  if (length(paths) == 0) return("")
  paths <- gsub("\\\\", "/", paths)
  quoted <- paste0('"', paths, '"')
  if (length(quoted) == 1) return(quoted)
  paste0("c(\n  ", paste(quoted, collapse = ",\n  "), "\n)")
}

# TRUE for files daos::read_files() can open, judged by extension. Folders
# and unknown extensions are FALSE. Vectorised.
.bf_readable <- function(path) {
  ext <- tolower(tools::file_ext(path))
  nzchar(ext) & ext %in% .read_files_exts()
}

# Plain-text extensions we show a quick first-lines peek for, so you can see
# what a script/config holds without opening it.
.bf_text_exts <- function()
  c("r", "rmd", "qmd", "txt", "md", "sql", "py", "js", "ts", "css", "scss",
    "html", "xml", "yaml", "yml", "json", "toml", "sh", "bat", "ps1", "log",
    "ini", "cfg", "conf", "csv", "tsv", "tex")

# Reader-mode expression. A single file reads inline -- read_files("x") --
# since an intermediate object would just be noise. Several paths are bound
# to `my_paths` first (a blank line, then the read), so the vector is named
# and left around to reuse. read_files() detects the format either way. It is
# namespaced as daos::read_files() so the pasted line runs even when the
# package was only reached via daos::browse_files(), without library(daos).
.bf_reader_expr <- function(paths) {
  s <- .bf_rstring(paths)
  if (length(paths) <= 1) {
    paste0("daos::read_files(", s, ")")
  } else {
    paste0("my_paths <- ", s, "\n\ndaos::read_files(my_paths)")
  }
}

# The text that gets inserted/copied. Plain paths by default; in reader mode
# only the *readable* files are wrapped in read_files() -- directories and
# files read_files() cannot open (by extension) are left out, since wrapping
# them would just produce a call that errors. A target with nothing readable
# is thus unchanged by reader mode.
.bf_expr <- function(paths, reader) {
  if (!reader || length(paths) == 0) return(.bf_rstring(paths))
  readable <- paths[!dir.exists(paths) & .bf_readable(paths)]
  if (length(readable) == 0) .bf_rstring(paths) else .bf_reader_expr(readable)
}

# Turn an Excel sheet name into a valid, unique R variable name for the
# generated code: lowercased, non-alphanumerics to "_", a leading digit or
# empty name prefixed with "ark_", duplicates disambiguated.
.bf_sheet_var <- function(sheets) {
  v <- tolower(sheets)
  v <- gsub("[^a-z0-9]+", "_", v)
  v <- gsub("^_+|_+$", "", v)
  bad <- !nzchar(v) | grepl("^[0-9]", v)
  v[bad] <- paste0("ark_", v[bad])
  make.unique(v, sep = "_")
}

# Code reading the chosen sheets of one workbook. One sheet reads inline; for
# several, one aligned assignment per sheet (the "one object per sheet" shape),
# each via daos::read_files(path, sheet = ...).
.bf_sheet_expr <- function(path, sheets) {
  if (length(sheets) == 0) return("")
  p <- gsub("\\\\", "/", path)
  if (length(sheets) == 1)
    return(sprintf('daos::read_files("%s", sheet = "%s")', p, sheets))
  vars <- .bf_sheet_var(sheets)
  sprintf('%-*s <- daos::read_files("%s", sheet = "%s")',
          max(nchar(vars)), vars, p, sheets) |>
    paste(collapse = "\n")
}

# The row icon: a blue folder, a green document for files read_files() can
# read, or a grey document for everything else -- so readable files stand
# out while browsing.
.bf_icon <- function(type, full) {
  if (identical(type, "d"))
    return(shiny::span(class = "bf-ico bf-ico-d", "\U0001F4C1"))
  if (tolower(tools::file_ext(full)) %in% c("xlsx", "xls"))
    return(shiny::span(class = "bf-ico bf-ico-xlsx", "\U0001F4D7"))  # green book: enterable
  cls <- if (isTRUE(.bf_readable(full))) "bf-ico bf-ico-readable" else "bf-ico bf-ico-f"
  shiny::span(class = cls, "\U0001F4C4")
}

# Open a file in its default application (Windows shell, macOS open, Linux
# xdg-open). Unlike open_in_explorer(), which reveals the file's location.
.bf_open_file <- function(path) {
  p <- normalizePath(path, mustWork = FALSE)
  if (.Platform$OS.type == "windows") {
    shell.exec(p)
  } else {
    opener <- if (Sys.info()[["sysname"]] == "Darwin") "open" else "xdg-open"
    system2(opener, shQuote(p), wait = FALSE,
            stdout = FALSE, stderr = FALSE)
  }
  invisible(path)
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
#'   The *target* is the marked paths, or the cursor path when none are
#'   marked.
#' - `Enter` (or the button) inserts the target into the active RStudio
#'   editor or console as an R expression and closes the app -- a quoted
#'   string for one path, a multi-line `c(...)` (one path per line) for
#'   several, with forward slashes. Outside RStudio it falls back to the
#'   clipboard.
#' - `r` toggles *reader mode*: when on, `Enter` and `y` read the target with
#'   [daos::read_files()] instead of inserting the bare path. A single file is
#'   read inline (`daos::read_files("data/x.tsv")`); several paths are bound to a
#'   `my_paths` object first, then read after a blank line
#'   (`my_paths <- c(...)` then `daos::read_files(my_paths)`). Only files
#'   [daos::read_files()] can open are wrapped; folders and files of an
#'   unsupported type are left out (with a warning), since wrapping them
#'   would only produce a call that errors. Readable files are flagged with a
#'   green icon in the browser. Toggle it off to go back to plain paths.
#' - On an Excel file (`.xlsx`/`.xls`), `l`/Enter steps *into* the workbook
#'   and lists its sheets; mark sheets with `Space` and the inserted code
#'   reads exactly those -- one [daos::read_files()] call per sheet (a single
#'   sheet reads inline). The preview shows the first rows of the sheet under
#'   the cursor. `h` leaves the workbook. Needs `readxl`.
#' - `y` copies that same expression to the clipboard without closing.
#' - `o` opens the item under the cursor in the system file explorer via
#'   [daos::open_in_explorer()] (a folder opens, a file is revealed).
#' - `a` opens the file itself in its default application (the workbook when
#'   inside one).
#' - `l`/`->` enters a folder; `h`/`<-` goes up, all the way to the drive
#'   chooser at the root. The cursor remembers its place in each folder,
#'   so going back up lands on the folder you came from. `g` jumps back to
#'   the directory the browser opened in.
#' - `Q` closes the app without inserting.
#'
#' @param path Directory to start in. Default: the working directory
#'   ([getwd()]).
#'
#' @return The target paths, invisibly -- a single string when one path
#'   is marked or the cursor path is used, a character vector when
#'   several are marked. `character(0)` if nothing is resolved.
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

  # Carries the result out of the app: the chosen paths, and whether the
  # user asked to insert them into the editor (Enter) or just close (Q).
  result <- new.env(parent = emptyenv())
  result$paths  <- character()
  result$insert <- FALSE
  result$expr   <- ""

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
    .bf-ico-readable { color: #16a34a; }
    .bf-ico-xlsx { color: #16a34a; }
    .bf-item.bf-xlsx { color: #15803d; font-weight: 600; }
    .bf-item.bf-xlsx:hover { background: #dcfce7; }
    .bf-enter { float: right; color: #16a34a; font-weight: 700; font-size: 11.5px;
      letter-spacing: .3px; margin-left: 8px; opacity: .55; }
    .bf-item.bf-xlsx:hover .bf-enter, .bf-item.bf-xlsx.cursor .bf-enter { opacity: 1; }
    .bf-check { color: #16a34a; float: right; margin-left: 8px; font-weight: 700; }
    .bf-item.sb-faux, .bf-faux { background: #eef4fb; color: #1d62a8; font-weight: 600; cursor: default; }
    .bf-faux:hover { background: #eef4fb; }
    .bf-preview-ro { cursor: default; color: #475569; }
    .bf-preview-ro:hover { background: transparent; }
    .bf-empty { text-align: center; padding: 28px 12px; color: #64748b; }
    .bf-empty-ico { font-size: 30px; margin-bottom: 6px; }
    .bf-empty p { margin: 2px 0; }
    .bf-fileinfo { padding: 10px 8px; }
    .bf-fileinfo strong { color: #0f3b66; word-break: break-all; }
    .bf-fileinfo p { color: #64748b; font-size: 12.5px; margin: 6px 0 2px; }
    .bf-read-ok { color: #16a34a !important; font-weight: 600; }
    .bf-read-no { color: #b45309 !important; font-weight: 600; }
    .bf-sheets { margin: 8px 0 2px; }
    .bf-sheets-head { color: #0f3b66; font-weight: 600; font-size: 12.5px; margin: 0 0 4px; }
    .bf-sheet-chip { display: inline-block; background: #e8f0fa; color: #1d62a8;
      border-radius: 999px; padding: 2px 10px; font-size: 12px; margin: 0 4px 4px 0; }
    .bf-sheet-peek { overflow-x: auto; margin: 6px 0; }
    .bf-sheet-peek table { border-collapse: collapse; font-size: 11.5px; width: 100%; }
    .bf-sheet-peek th, .bf-sheet-peek td { border: 1px solid #e2e8f0; padding: 3px 7px;
      text-align: left; white-space: nowrap; max-width: 140px; overflow: hidden; text-overflow: ellipsis; }
    .bf-sheet-peek th { background: #f1f5f9; color: #475569; font-weight: 600; }
    .bf-code-peek { background: #0f172a; color: #e2e8f0; border-radius: 8px;
      padding: 10px 12px; font-family: ui-monospace, Consolas, monospace;
      font-size: 11.5px; line-height: 1.5; white-space: pre; overflow: auto;
      max-height: 42vh; margin: 8px 0; }
    .bf-crumb-file { color: #16a34a; font-weight: 700; }
    .bf-col-current.bf-sheet-mode { border-color: #bbf7d0; }
    .bf-col-current.bf-sheet-mode .bf-colhead { color: #16a34a; }
    /* Inside a workbook the cursor and the marked rows go Excel-green. */
    .bf-sheet-mode .bf-item.cursor { outline-color: #16a34a; background: #dcfce7; }
    .bf-sheet-mode .bf-item.marked { background: #bbf7d0; }
    .bf-sheet-mode .bf-item.marked.cursor { background: #86efac; }
    .bf-in-xlsx .bf-hero { background: linear-gradient(135deg, #14532d 0%, #16a34a 100%); }
    .bf-in-xlsx .bf-hero .bf-sub { color: #d7f5e1; }
    .bf-hint { color: #64748b; font-size: 12.5px; }
    .bf-bar { margin-top: 16px; padding-top: 16px; border-top: 1px solid #eef2f7; }
    .bf-actions { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; margin-bottom: 14px; }
    .bf-btn {
      border-radius: 9px; font-weight: 600; padding: 8px 16px;
      display: inline-flex; align-items: center; gap: 8px;
      border: 1px solid #d6dee8; box-shadow: 0 1px 2px rgba(15,23,42,.05);
    }
    .bf-btn.btn-primary { background: #174e86; border-color: #174e86; color: #fff; }
    .bf-btn.btn-primary:hover { background: #123e6c; border-color: #123e6c; }
    .bf-btn.btn-default { background: #fff; color: #334155; }
    .bf-btn.btn-default:hover { border-color: #1d62a8; color: #1d62a8; }
    .bf-kbd {
      font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 11px;
      background: rgba(15,23,42,.08); border-radius: 5px; padding: 1px 6px;
    }
    .bf-btn.btn-primary .bf-kbd { background: rgba(255,255,255,.3); color: #fff; }
    .bf-info {
      display: inline-flex; align-items: center; gap: 8px;
      border-radius: 9px; font-weight: 600; font-size: 13px;
      padding: 8px 16px; color: #1d62a8; background: #e8f0fa;
      border: 1px solid #cfe0f2;
    }
    .bf-info code {
      background: rgba(29,98,168,.12); color: #174e86;
      border-radius: 5px; padding: 1px 6px; font-size: 12px;
    }
    .bf-info-warn { color: #b45309; background: #fef3c7; border-color: #fbdca0; }
    .bf-info-warn code { background: rgba(180,83,9,.12); color: #92400e; }
    .bf-chip {
      margin-left: auto; color: #16a34a; font-size: 13px; font-weight: 600;
      background: #dcfce7; border-radius: 999px; padding: 5px 14px;
    }
    .bf-selhead {
      font-size: 11.5px; font-weight: 700; letter-spacing: .4px;
      text-transform: uppercase; color: #94a3b8; margin-bottom: 5px;
    }
    .bf-selbox pre {
      background: #0f172a; color: #e2e8f0; border-radius: 8px; padding: 12px 14px;
      font-size: 12.5px; margin: 0; white-space: pre-wrap; word-break: break-all;
      min-height: 20px;
    }
    .bf-legend { margin-top: 14px; font-size: 12px; color: #64748b; }
    .bf-legend .bf-kbd { margin: 0 3px 0 10px; }
    .bf-legend .bf-kbd:first-child { margin-left: 0; }
  "

  app_js <- "
    document.addEventListener('keydown', function(e) {
      var t = (e.target.tagName || '').toLowerCase();
      if (t === 'input' || t === 'textarea' || t === 'select') return;
      if (e.key === 'q' || e.key === 'Q') { Shiny.setInputValue('quit', Date.now()); return; }
      if (e.key === 'Enter' && (t === 'button' || t === 'a')) return;
      if (document.querySelector('.modal-backdrop')) return;

      var key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      if (key === 'Enter') { e.preventDefault(); Shiny.setInputValue('do_insert', Date.now()); return; }
      if (key === 'y') { e.preventDefault(); Shiny.setInputValue('do_copy', Date.now()); return; }
      if (key === 'o') { e.preventDefault(); Shiny.setInputValue('do_open', Date.now()); return; }
      if (key === 'a') { e.preventDefault(); Shiny.setInputValue('do_openfile', Date.now()); return; }
      if (key === 'g') { e.preventDefault(); Shiny.setInputValue('go_start', Date.now()); return; }
      if (key === 'r') { e.preventDefault(); Shiny.setInputValue('toggle_reader', Date.now()); return; }

      var down = (key === 'j' || key === 'ArrowDown');
      var up   = (key === 'k' || key === 'ArrowUp');
      var open = (key === 'l' || key === 'ArrowRight');
      var back = (key === 'h' || key === 'ArrowLeft');
      var mark = (key === ' ' || e.code === 'Space');
      if (!(down || up || open || back || mark)) return;
      e.preventDefault();

      function goUp() {
        var crumbs = document.querySelectorAll('.bf-crumbs a');
        if (crumbs.length >= 2) crumbs[crumbs.length - 2].click();
      }
      // Inside an Excel file, h/left leaves the sheet view; otherwise it
      // climbs to the parent directory.
      function goBack() {
        if (document.querySelector('.bf-col-current.bf-sheet-mode'))
          Shiny.setInputValue('exit_xlsx', Date.now());
        else goUp();
      }

      // An empty folder has no rows; h/left must still get you back out.
      var items = document.querySelectorAll('.bf-col-current .bf-item');
      if (items.length === 0) { if (back) goBack(); return; }

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
        goBack();
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
    // Turn the banner green while inside an Excel workbook.
    Shiny.addCustomMessageHandler('bf_xlsx_mode', function(on) {
      document.body.classList.toggle('bf-in-xlsx', !!on);
    });
  "

  kbd_html <- function(k) paste0("<span class='bf-kbd'>", k, "</span>")
  legend_html <- paste0(
    kbd_html("j"), kbd_html("k"), " flyt ",
    kbd_html("l"), " \u00e5bn ", kbd_html("h"), " op ",
    kbd_html("mellemrum"), " mark\u00e9r ",
    kbd_html("Enter"), " inds\u00e6t ", kbd_html("y"), " kopier ",
    kbd_html("r"), " reader ",
    kbd_html("o"), " stifinder ", kbd_html("a"), " \u00e5bn fil ",
    kbd_html("g"), " start ", kbd_html("Q"), " luk",
    "<br>", kbd_html("l"), " p\u00e5 en Excel-fil g\u00e5r ind i arkene"
  )

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
        shiny::uiOutput("actions"),
        shiny::div(
          class = "bf-selbox",
          shiny::div(class = "bf-selhead", "Bliver indsat / kopieret"),
          shiny::tags$pre(shiny::textOutput("rstring"))
        ),
        shiny::div(class = "bf-legend", shiny::HTML(legend_html))
      )
    )
  )

  server <- function(input, output, session) {
    cur_path <- shiny::reactiveVal(start_path)
    cursor   <- shiny::reactiveVal(NULL)
    marked   <- shiny::reactiveVal(character())
    reader   <- shiny::reactiveVal(FALSE)
    has_readxl <- requireNamespace("readxl", quietly = TRUE)

    # Excel "module": when sheet_file is set, the browser is inside that
    # workbook -- the current column lists its sheets to mark instead of
    # files, and the insert reads the chosen sheets with read_files().
    sheet_file   <- shiny::reactiveVal(NULL)
    sheet_cursor <- shiny::reactiveVal(NULL)
    sheet_marked <- shiny::reactiveVal(character())
    sheet_cache  <- new.env(parent = emptyenv())
    sheets_of <- function(path) {
      if (is.null(sheet_cache[[path]]))
        sheet_cache[[path]] <- tryCatch(readxl::excel_sheets(path), error = function(e) character())
      sheet_cache[[path]]
    }

    cache <- new.env(parent = emptyenv())
    listing <- function(dir) {
      key <- dir
      if (is.null(cache[[key]])) cache[[key]] <- .bf_list(dir)
      cache[[key]]
    }

    # Target set: the marked paths, or the cursor path when nothing is
    # marked. Drives every action and the return value.
    target <- shiny::reactive({
      m <- marked()
      if (length(m) > 0) return(m)
      cu <- cursor()
      if (!is.null(cu)) cu$full else character()
    })
    # Inside a workbook: the marked sheets, or the cursor sheet.
    sheet_target <- shiny::reactive({
      m <- sheet_marked()
      if (length(m) > 0) return(m)
      cs <- sheet_cursor(); if (!is.null(cs)) cs else character()
    })
    # The text that gets inserted/copied, for whichever mode is active.
    current_expr <- shiny::reactive({
      if (!is.null(sheet_file())) .bf_sheet_expr(sheet_file(), sheet_target())
      else .bf_expr(target(), reader())
    })

    # Per-directory cursor memory (plain env, non-reactive). `mem` maps a
    # directory to the path the cursor last sat on there; `prev` is the
    # directory we just left, so going up lands on the folder we came
    # from -- both consulted by initial_cursor().
    nav <- new.env(parent = emptyenv())
    nav$mem  <- list()
    nav$prev <- NULL

    initial_cursor <- function(dir) {
      nodes <- listing(dir)
      if (nrow(nodes) == 0) return(NULL)
      pick <- NULL
      if (!is.null(nav$prev) && nav$prev %in% nodes$full) pick <- nav$prev
      if (is.null(pick)) {
        m <- nav$mem[[dir]]
        if (!is.null(m) && m %in% nodes$full) pick <- m
      }
      if (is.null(pick)) pick <- nodes$full[1]
      i <- match(pick, nodes$full)
      list(full = nodes$full[i], type = nodes$type[i])
    }

    finish <- function(insert) {
      result$expr   <- current_expr()
      result$paths  <- if (!is.null(sheet_file())) sheet_target() else target()
      result$insert <- insert
      shiny::stopApp()
    }
    shiny::observeEvent(input$quit, finish(FALSE))
    shiny::observeEvent(input$do_insert, finish(TRUE))
    shiny::observeEvent(input$toggle_reader, reader(!reader()))

    # Enter a workbook (l/click on an .xlsx); leave it (h) back to the file.
    shiny::observeEvent(input$enter_xlsx, {
      path <- input$enter_xlsx
      sheet_file(path); sheet_marked(character())
      s <- sheets_of(path)
      sheet_cursor(if (length(s)) s[1] else NULL)
    })
    shiny::observeEvent(input$exit_xlsx, {
      f <- sheet_file()
      sheet_file(NULL); sheet_marked(character()); sheet_cursor(NULL)
      if (!is.null(f)) cursor(list(full = f, type = "f"))
    })
    shiny::observeEvent(input$pick_sheet, sheet_cursor(input$pick_sheet))

    # Green banner while inside a workbook.
    shiny::observe(session$sendCustomMessage("bf_xlsx_mode", !is.null(sheet_file())))

    # Place the cursor when the directory changes, honouring the memory.
    shiny::observe({
      cursor(initial_cursor(cur_path()))
    })
    shiny::observeEvent(input$bf_cursor, {
      if (!is.null(sheet_file()) && identical(input$bf_cursor$type, "x")) {
        sheet_cursor(input$bf_cursor$full)
      } else {
        cursor(list(full = input$bf_cursor$full, type = input$bf_cursor$type))
        nav$mem[[cur_path()]] <- input$bf_cursor$full
      }
    })

    shiny::observeEvent(input$bf_toggle, {
      p <- input$bf_toggle$full
      if (!is.null(sheet_file())) {
        m <- sheet_marked()
        if (p %in% m) sheet_marked(setdiff(m, p)) else sheet_marked(c(m, p))
      } else {
        m <- marked()
        if (p %in% m) marked(setdiff(m, p)) else marked(c(m, p))
      }
    })

    shiny::observeEvent(input$go, {
      sheet_file(NULL); sheet_marked(character()); sheet_cursor(NULL)
      old <- cur_path()
      nav$prev <- old
      # Descending into a child: remember it as our place in the parent.
      if (identical(normalizePath(dirname(input$go), winslash = "/", mustWork = FALSE), old)) {
        nav$mem[[old]] <- input$go
      }
      cur_path(input$go)
    })
    shiny::observeEvent(input$pick_file, {
      cursor(list(full = input$pick_file, type = "f"))
      nav$mem[[cur_path()]] <- input$pick_file
    })

    # Clicking a folder navigates; clicking a file selects it (so it can
    # be copied or opened). Both carry data attributes for the keyboard
    # handler.
    item_row <- function(row, cursor_on = FALSE) {
      marked_now <- row$full %in% marked()
      cls <- c("bf-item", paste0("bf-row-", row$type),
               if (cursor_on) "cursor", if (marked_now) "marked")
      is_xlsx <- has_readxl && tolower(tools::file_ext(row$full)) %in% c("xlsx", "xls")
      onclick <- if (row$type == "d") {
        sprintf("Shiny.setInputValue('go', '%s', {priority:'event'})", row$full)
      } else if (is_xlsx) {
        # l/click descends into the workbook's sheets; Space still marks the
        # file path itself.
        sprintf("Shiny.setInputValue('enter_xlsx', '%s', {priority:'event'})", row$full)
      } else {
        sprintf("Shiny.setInputValue('pick_file', '%s', {priority:'event'})", row$full)
      }
      shiny::div(
        class = paste(c(cls, if (is_xlsx) "bf-xlsx"), collapse = " "),
        `data-full` = row$full, `data-type` = row$type, onclick = onclick,
        .bf_icon(row$type, row$full),
        row$name,
        if (marked_now) shiny::span(class = "bf-check", "\u2713"),
        if (is_xlsx) shiny::span(class = "bf-enter", "\u203a ark")   # go-deeper hint
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
      # Inside a workbook, show its name as the last (non-link) crumb.
      if (!is.null(sheet_file()))
        crumbs <- c(crumbs, list(
          shiny::span(class = "bf-sep", "/"),
          shiny::span(class = "bf-crumb-file", paste0("\U0001F4D7 ", basename(sheet_file())))))
      crumbs
    })

    output$browser <- shiny::renderUI({
      # Inside a workbook: list its sheets to mark, with the folder on the
      # left and a peek on the right.
      sf <- sheet_file()
      if (!is.null(sf)) {
        sheets <- sheets_of(sf); scur <- sheet_cursor(); smark <- sheet_marked()
        sheet_row <- function(s) {
          marked_now <- s %in% smark
          cls <- c("bf-item", if (!is.null(scur) && s == scur) "cursor", if (marked_now) "marked")
          js_s <- gsub("'", "\\'", s, fixed = TRUE)   # sheet names may contain '
          shiny::div(
            class = paste(cls, collapse = " "),
            `data-full` = s, `data-type` = "x",
            onclick = sprintf("Shiny.setInputValue('pick_sheet', '%s', {priority:'event'})", js_s),
            shiny::span(class = "bf-ico bf-ico-readable", "\U0001F4D1"), s,
            if (marked_now) shiny::span(class = "bf-check", "✓"))
        }
        cur_col <- shiny::div(
          class = "bf-col bf-col-current bf-sheet-mode",
          shiny::div(class = "bf-colhead", paste0("\U0001F4D7 ", basename(sf))),
          if (length(sheets) == 0)
            shiny::div(class = "bf-empty",
              shiny::div(class = "bf-empty-ico", "\U0001F4D6"),
              shiny::p(shiny::strong("Ingen ark")),
              shiny::p(class = "bf-hint", "Tryk h for at gå tilbage."))
          else lapply(sheets, sheet_row))
        path  <- cur_path(); nodes <- listing(path)
        parent_col <- shiny::div(
          class = "bf-col",
          shiny::div(class = "bf-colhead", basename(path)),
          lapply(seq_len(nrow(nodes)), function(i) {
            row <- nodes[i, ]
            active <- normalizePath(row$full, winslash = "/", mustWork = FALSE) ==
                      normalizePath(sf, winslash = "/", mustWork = FALSE)
            shiny::div(
              class = paste(c("bf-item", if (active) "active"), collapse = " "),
              onclick = if (row$type == "d")
                sprintf("Shiny.setInputValue('go', '%s', {priority:'event'})", row$full)
              else if (has_readxl && tolower(tools::file_ext(row$full)) %in% c("xlsx", "xls"))
                sprintf("Shiny.setInputValue('enter_xlsx', '%s', {priority:'event'})", row$full),
              .bf_icon(row$type, row$full), row$name)
          }))
        preview_col <- shiny::div(
          class = "bf-col bf-col-preview",
          shiny::div(class = "bf-colhead", "Ark-preview"),
          shiny::uiOutput("preview"))
        return(shiny::div(class = "bf-browser", parent_col, cur_col, preview_col))
      }

      path <- cur_path()
      nodes <- listing(path)

      init <- initial_cursor(path)
      cur_col <- shiny::div(
        class = "bf-col bf-col-current",
        shiny::div(class = "bf-colhead", basename(path)),
        if (nrow(nodes) == 0)
          shiny::div(
            class = "bf-empty",
            shiny::div(class = "bf-empty-ico", "\U0001F4ED"),
            shiny::p(shiny::strong("Tom mappe")),
            shiny::p(class = "bf-hint", "Tryk h eller \u2190 for at g\u00e5 tilbage.")
          )
        else lapply(seq_len(nrow(nodes)), function(i) {
          item_row(nodes[i, ], cursor_on = !is.null(init) && nodes$full[i] == init$full)
        })
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
              .bf_icon(row$type, row$full),
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
      # Inside a workbook: peek at the first rows of the cursor sheet.
      sf <- sheet_file()
      if (!is.null(sf)) {
        s <- sheet_cursor()
        if (is.null(s)) return(NULL)
        df <- tryCatch(readxl::read_excel(sf, sheet = s, n_max = 8),
                       error = function(e) NULL)
        if (is.null(df) || ncol(df) == 0)
          return(shiny::div(class = "bf-fileinfo",
            shiny::p(shiny::span(class = "bf-ico bf-ico-readable", "\U0001F4D1"), shiny::strong(s)),
            shiny::p(class = "bf-hint", "Tomt eller ulæseligt ark.")))
        ncol_total <- ncol(df); nrow_show <- nrow(df)
        nshow <- min(ncol_total, 6L)
        df <- df[, seq_len(nshow), drop = FALSE]
        cell <- function(v) { v <- format(v); if (is.na(v) || v == "NA") "" else v }
        tbl <- shiny::tags$table(
          shiny::tags$tr(lapply(names(df), function(nm) shiny::tags$th(nm))),
          lapply(seq_len(nrow(df)), function(r)
            shiny::tags$tr(lapply(df[r, , drop = TRUE], function(v) shiny::tags$td(cell(v))))))
        return(shiny::div(class = "bf-fileinfo",
          shiny::p(shiny::span(class = "bf-ico bf-ico-readable", "\U0001F4D1"), shiny::strong(s)),
          shiny::div(class = "bf-sheet-peek", tbl),
          shiny::p(class = "bf-hint",
            paste0("Første ", nrow_show, " rækker · ",
                   if (ncol_total > nshow) paste0(nshow, " af ", ncol_total) else ncol_total,
                   " kolonner")),
          shiny::p(class = "bf-hint", "Mellemrum markérer ark · Enter indsætter · h tilbage")))
      }
      cu <- cursor()
      if (is.null(cu)) return(NULL)
      if (identical(cu$type, "d")) {
        kids <- listing(cu$full)
        if (nrow(kids) == 0) return(shiny::p(class = "bf-hint", style = "padding:8px;", "Tom mappe."))
        lapply(seq_len(nrow(kids)), function(i) {
          row <- kids[i, ]
          shiny::div(
            class = "bf-item bf-preview-ro",
            .bf_icon(row$type, row$full),
            row$name
          )
        })
      } else {
        info <- file.info(cu$full)
        ext  <- tools::file_ext(cu$full)
        ts   <- function(x) if (length(x) == 0 || is.na(x)) NULL else format(x, "%Y-%m-%d %H:%M")
        readable <- isTRUE(.bf_readable(cu$full))
        # For Excel files, peek at the sheet names (cheap -- excel_sheets()
        # reads only the workbook structure, not the cells), so you can see
        # there is more than one before reading.
        sheets <- if (tolower(ext) %in% c("xlsx", "xls") &&
                      requireNamespace("readxl", quietly = TRUE))
          tryCatch(readxl::excel_sheets(cu$full), error = function(e) NULL)
        # For scripts/text, peek at the first lines so you can recall what a
        # file holds without opening it. Read one extra line to detect "more".
        peek <- if (tolower(ext) %in% .bf_text_exts())
          tryCatch(readLines(cu$full, n = 41, warn = FALSE, encoding = "UTF-8"),
                   error = function(e) NULL)
        code_block <- if (length(peek)) shiny::tagList(
          shiny::tags$pre(class = "bf-code-peek", paste(utils::head(peek, 40), collapse = "\n")),
          if (length(peek) > 40) shiny::p(class = "bf-hint", "\u2026 (f\u00f8rste 40 linjer)"))
        shiny::div(
          class = "bf-fileinfo",
          shiny::p(.bf_icon("f", cu$full), shiny::strong(basename(cu$full))),
          shiny::p(paste0("St\u00f8rrelse: ", .bf_size(info$size))),
          if (nzchar(ext)) shiny::p(paste0("Type: .", ext)),
          code_block,
          if (!is.null(ts(info$ctime))) shiny::p(paste0("Oprettet: ", ts(info$ctime))),
          if (!is.null(ts(info$mtime))) shiny::p(paste0("\u00c6ndret: ", ts(info$mtime))),
          if (!is.null(ts(info$atime))) shiny::p(paste0("Tilg\u00e5et: ", ts(info$atime))),
          if (length(sheets)) shiny::div(
            class = "bf-sheets",
            shiny::p(class = "bf-sheets-head", paste0(length(sheets), " ark:")),
            lapply(sheets, function(s) shiny::span(class = "bf-sheet-chip", s))),
          if (nzchar(ext)) shiny::p(
            class = if (readable) "bf-read-ok" else "bf-read-no",
            if (readable) "\u2713 Kan l\u00e6ses med read_files()"
            else paste0("\u2717 read_files() underst\u00f8tter ikke .", ext)),
          if (length(sheets) > 1) shiny::p(class = "bf-hint",
            "read_files() l\u00e6ser kun det f\u00f8rste ark \u2014 v\u00e6lg et andet med reader = \\(x) readxl::read_excel(x, sheet = \"...\")."),
          shiny::p(class = "bf-hint", "Mellemrum mark\u00e9rer \u00b7 Enter inds\u00e6tter \u00b7 r reader \u00b7 o \u00e5bner i stifinder.")
        )
      }
    })

    # The action buttons name exactly what they will act on: the number
    # of paths in the target set (marked, or the cursor when none are).
    kbd <- function(k) shiny::tags$span(class = "bf-kbd", k)
    output$actions <- shiny::renderUI({
      if (!is.null(sheet_file())) {
        nsh <- length(sheet_target()); nmk <- length(sheet_marked())
        info_txt <- if (nsh <= 1) "Excel — indsætter <code>read_files(sheet = ...)</code>"
                    else paste0("Excel — ", nsh, " ark, hvert sit objekt")
        return(shiny::div(
          class = "bf-actions",
          shiny::actionButton("do_insert",
            shiny::tagList(paste("Indsæt", max(nsh, 1L), "ark"), kbd("Enter")),
            icon = shiny::icon("file-import"), class = "btn-default bf-btn"),
          shiny::actionButton("do_copy", shiny::tagList("Kopier", kbd("y")),
            icon = shiny::icon("copy"), class = "btn-default bf-btn"),
          shiny::actionButton("do_openfile", shiny::tagList("Åbn fil", kbd("a")),
            icon = shiny::icon("external-link-alt"), class = "btn-default bf-btn"),
          shiny::span(class = "bf-info", shiny::icon("table"), shiny::HTML(info_txt)),
          if (nmk > 0) shiny::span(class = "bf-chip", paste(nmk, "ark markeret"))))
      }
      tg <- target()
      n  <- length(tg)
      nm <- length(marked())
      on <- reader()
      # Reader only wraps files read_files() can open. Folders and unreadable
      # files are excluded, so the button and shape follow the readable count,
      # and the note names what is being left out.
      files   <- if (on && n > 0) tg[!dir.exists(tg)] else character()
      n_dirs  <- if (on && n > 0) n - length(files) else 0L
      read_ok <- if (length(files)) files[.bf_readable(files)] else character()
      n_read  <- length(read_ok)
      n_bad   <- length(files) - n_read
      active  <- on && n_read > 0
      warn    <- on && n_bad > 0

      label <- if (active) "Inds\u00e6t read_files()" else {
        paste("Inds\u00e6t", if (n <= 1) "sti" else paste(n, "stier"))
      }
      ex <- character()
      if (n_bad > 0)  ex <- c(ex, paste0(n_bad, if (n_bad == 1) " fil" else " filer", " read_files ikke kan l\u00e6se"))
      if (n_dirs > 0) ex <- c(ex, paste0(n_dirs, if (n_dirs == 1) " mappe" else " mapper"))
      info <- if (!on) NULL else if (!active) {
        if (warn) "Reader til \u2014 read_files() kan ikke l\u00e6se det valgte, inds\u00e6tter sti"
        else "Reader til \u2014 mapper kan ikke l\u00e6ses, inds\u00e6tter sti"
      } else {
        paste0(
          "Reader til \u2014 inds\u00e6tter <code>",
          if (n_read <= 1) "daos::read_files(...)" else "daos::read_files(my_paths)",
          "</code>",
          if (length(ex)) paste0(" \u00b7 udelader ", paste(ex, collapse = " og ")) else "")
      }
      shiny::div(
        class = "bf-actions",
        shiny::actionButton(
          "do_insert", shiny::tagList(label, kbd("Enter")),
          icon = shiny::icon("file-import"), class = "btn-default bf-btn"),
        shiny::actionButton(
          "do_copy", shiny::tagList("Kopier", kbd("y")),
          icon = shiny::icon("copy"), class = "btn-default bf-btn"),
        shiny::actionButton(
          "do_open", shiny::tagList("\u00c5bn i stifinder", kbd("o")),
          icon = shiny::icon("folder-open"), class = "btn-default bf-btn"),
        shiny::actionButton(
          "do_openfile", shiny::tagList("\u00c5bn fil", kbd("a")),
          icon = shiny::icon("external-link-alt"), class = "btn-default bf-btn"),
        if (!is.null(info))
          shiny::span(class = if (warn) "bf-info bf-info-warn" else "bf-info",
                      shiny::icon(if (warn) "exclamation-triangle" else "info-circle"),
                      shiny::HTML(info)),
        if (nm > 0)
          shiny::span(class = "bf-chip",
                      paste(nm, if (nm == 1) "markeret" else "markerede"))
      )
    })

    output$rstring <- shiny::renderText({
      e <- current_expr()
      if (!nzchar(e)) "(intet valgt)" else e
    })

    shiny::observeEvent(input$do_copy, {
      e <- current_expr()
      if (nzchar(e)) {
        session$sendCustomMessage("bf_clip", e)
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
    # Open the file itself in its default application: the workbook when
    # inside one, otherwise the cursor file (not directories).
    shiny::observeEvent(input$do_openfile, {
      f <- if (!is.null(sheet_file())) sheet_file()
           else { cu <- cursor(); if (!is.null(cu) && identical(cu$type, "f")) cu$full else NULL }
      if (!is.null(f))
        tryCatch(.bf_open_file(f),
                 error = function(e) shiny::showNotification(conditionMessage(e),
                                                             duration = 4, type = "error"))
    })
    # Jump back to the directory the browser opened in.
    shiny::observeEvent(input$go_start, {
      sheet_file(NULL); sheet_marked(character()); sheet_cursor(NULL)
      nav$prev <- cur_path()
      cur_path(start_path)
    })
  }

  shiny::runApp(shiny::shinyApp(ui, server), quiet = TRUE)

  # Deliver the result after the app has closed, so the active document
  # is the user's script/console again, not the app viewer.
  if (result$insert && nzchar(result$expr)) {
    expr <- result$expr
    if (requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
      rstudioapi::insertText(expr)
    } else if (.Platform$OS.type == "windows") {
      utils::writeClipboard(expr)
      cli::cli_alert_info("Not in RStudio -- copied to the clipboard instead.")
    } else {
      cli::cli_alert_info("Not in RStudio -- returning the paths.")
    }
  }
  invisible(result$paths)
}
