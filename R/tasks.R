# A small taskwarrior-style task manager over a shared SQLite database.
# SQLite (public domain, bundled by RSQLite) is used in WAL mode so that
# several R processes can read and write the same .sqlite file on a shared
# drive concurrently. Every function opens a short-lived connection (or
# reuses a supplied DBIConnection), works in one transaction, and closes.

# --- connection + schema ------------------------------------------------------

.task_con <- function(db) {
  if (inherits(db, "DBIConnection")) return(list(con = db, close = FALSE))
  if (!is.character(db) || length(db) != 1)
    cli::cli_abort("{.arg db} must be a path to a .sqlite file or a DBI connection.")
  for (pkg in c("DBI", "RSQLite")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required. Install with {.code install.packages(c('DBI', 'RSQLite'))}.")
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  DBI::dbExecute(con, "PRAGMA journal_mode=WAL;")
  DBI::dbExecute(con, "PRAGMA busy_timeout=5000;")
  .task_ensure(con)
  list(con = con, close = TRUE)
}

# Run `fn(con)` against `db`, disconnecting afterwards only if we opened the
# connection -- a passed-in DBIConnection is left open for its owner. This is
# the open/work/close lifecycle every task_* function shares.
.task_with_con <- function(db, fn) {
  h <- .task_con(db)
  on.exit(if (h$close) DBI::dbDisconnect(h$con))
  fn(h$con)
}

# Create the schema only if it is missing, and add the assignee column to
# older databases. In steady state this is a single read (PRAGMA), so
# concurrent connections do not contend on DDL write locks.
.task_ensure <- function(con) {
  cols <- DBI::dbGetQuery(con, "PRAGMA table_info(tasks)")$name
  if (length(cols) == 0) { .task_schema(con); return(invisible(TRUE)) }
  if (!"assignee" %in% cols)
    DBI::dbExecute(con, "ALTER TABLE tasks ADD COLUMN assignee TEXT")
  # The user-chosen key: a slug to reference a task by in scripts instead of
  # the opaque id/uuid. ALTER cannot add UNIQUE, so uniqueness is a separate
  # index -- which also lets several keyless tasks coexist (NULLs are
  # distinct in a SQLite unique index). Both run once, on migration only.
  if (!"key" %in% cols) {
    DBI::dbExecute(con, "ALTER TABLE tasks ADD COLUMN key TEXT")
    DBI::dbExecute(con, "CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_key ON tasks(key)")
  }
  # `start` marks a task as in progress: a pending task with a non-NULL
  # start is being worked on right now (the taskwarrior "active" idea),
  # which is what lets the overview show what is happening rather than only
  # what is pending. Added to older databases here.
  if (!"start" %in% cols)
    DBI::dbExecute(con, "ALTER TABLE tasks ADD COLUMN start TEXT")
  invisible(TRUE)
}

.task_schema <- function(con) {
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT UNIQUE NOT NULL,
    key TEXT,
    description TEXT NOT NULL,
    project TEXT,
    assignee TEXT,
    priority TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    due TEXT,
    entry TEXT NOT NULL,
    modified TEXT NOT NULL,
    start TEXT,
    end TEXT,
    recur TEXT
  );")
  DBI::dbExecute(con, "CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_key ON tasks(key)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS task_tags (
    task_uuid TEXT NOT NULL, tag TEXT NOT NULL, UNIQUE(task_uuid, tag)
  );")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS annotations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_uuid TEXT NOT NULL, entry TEXT NOT NULL, text TEXT NOT NULL
  );")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS dependencies (
    task_uuid TEXT NOT NULL, depends_on_uuid TEXT NOT NULL,
    UNIQUE(task_uuid, depends_on_uuid)
  );")
  invisible(TRUE)
}

.task_uuid <- function() {
  h <- sprintf("%02x", sample.int(256, 16, replace = TRUE) - 1L)
  paste(paste0(h[1:4], collapse = ""), paste0(h[5:6], collapse = ""),
        paste0(h[7:8], collapse = ""), paste0(h[9:10], collapse = ""),
        paste0(h[11:16], collapse = ""), sep = "-")
}

.task_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

# A cheap signature of the whole database, for a poller to tell whether
# anything changed before re-rendering. Row counts plus the latest task
# `modified` and annotation `entry` catch adds, edits, completions,
# deletions, purges, and new notes -- so an unchanged database yields the
# same string and the UI can skip a redraw.
.task_fingerprint <- function(db) {
  .task_with_con(db, function(con) {
    r <- DBI::dbGetQuery(con,
      "SELECT (SELECT COUNT(*) FROM tasks)                    AS nt,
              (SELECT IFNULL(MAX(modified), '') FROM tasks)   AS mt,
              (SELECT COUNT(*) FROM annotations)              AS na,
              (SELECT IFNULL(MAX(entry), '') FROM annotations) AS ma,
              (SELECT COUNT(*) FROM dependencies)             AS nd")
    paste(r$nt, r$mt, r$na, r$ma, r$nd, sep = "|")
  })
}

.or_na <- function(x) if (is.null(x) || length(x) == 0) NA else x

# The canonical uuid shape (8-4-4-4-12 lowercase hex), used to tell a uuid
# apart from a user key when resolving an identifier.
.task_uuid_re <- "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

# Validate a user-chosen key. NULL/"" means "no key". A key must be a slug --
# lowercase letters/digits joined by single - or _ -- and must not be all
# digits or shaped like a uuid, so it can never be mistaken for an id or uuid
# when looked up. Returns the key, or NULL.
.task_check_key <- function(k) {
  if (is.null(k) || length(k) == 0 || (is.character(k) && !nzchar(k))) return(NULL)
  if (!is.character(k) || length(k) != 1)
    cli::cli_abort("{.arg key} must be a single string.")
  if (grepl("^[0-9]+$", k))
    cli::cli_abort(c("{.arg key} cannot be all digits -- it would clash with the numeric id.",
                     "i" = "Add a letter, e.g. {.val t-{k}}."))
  if (grepl(.task_uuid_re, k))
    cli::cli_abort("{.arg key} must not be shaped like a uuid.")
  if (!grepl("^[a-z0-9]+([-_][a-z0-9]+)*$", k))
    cli::cli_abort(c(
      "{.arg key} must be a slug: lowercase letters or digits, joined by single {.val -} or {.val _}.",
      "i" = "Got {.val {k}}."))
  k
}

.task_check_priority <- function(p) {
  if (is.null(p) || length(p) == 0 || (is.character(p) && !nzchar(p))) return(NULL)
  p <- toupper(substr(as.character(p), 1, 1))
  if (!p %in% c("H", "M", "L"))
    cli::cli_abort("{.arg priority} must be one of {.val H}, {.val M}, {.val L} (or NULL).")
  p
}

.task_norm_date <- function(d) {
  if (is.null(d) || length(d) == 0 || (is.character(d) && !nzchar(d))) return(NULL)
  if (inherits(d, "Date") || inherits(d, "POSIXt")) return(format(d, "%Y-%m-%d"))
  dd <- tryCatch(suppressWarnings(as.Date(d)), error = function(e) as.Date(NA))
  if (is.na(dd)) cli::cli_abort("Could not parse a date from {.val {d}} (use {.val YYYY-MM-DD}).")
  format(dd, "%Y-%m-%d")
}

# Advance a due date by a recurrence: an integer number of days, or one of
# daily/weekly/biweekly/monthly/quarterly/semiannual/yearly -- the
# cadences statistics production runs on.
.task_advance <- function(due, recur) {
  d <- as.Date(due)
  r <- tolower(trimws(recur))
  n <- suppressWarnings(as.integer(r))
  out <- if (!is.na(n)) d + n else switch(
    r,
    daily = d + 1, weekly = d + 7, biweekly = d + 14,
    monthly = seq(d, by = "month", length.out = 2)[2],
    quarterly = seq(d, by = "3 months", length.out = 2)[2],
    semiannual = , semiannually = , biannual = , halfyearly =
      seq(d, by = "6 months", length.out = 2)[2],
    yearly = , annually = seq(d, by = "year", length.out = 2)[2],
    d + 7
  )
  format(out, "%Y-%m-%d")
}

# Resolve an identifier to a task row. A pure number is the id, a uuid-shaped
# string is the uuid, and anything else is treated as a user key -- the three
# never overlap (see .task_check_key), so the lookup is unambiguous.
.task_row <- function(con, id) {
  idc <- as.character(id)
  row <- if (is.numeric(id) || grepl("^[0-9]+$", idc)) {
    DBI::dbGetQuery(con, "SELECT * FROM tasks WHERE id = ?", list(as.integer(id)))
  } else if (grepl(.task_uuid_re, idc)) {
    DBI::dbGetQuery(con, "SELECT * FROM tasks WHERE uuid = ?", list(idc))
  } else {
    DBI::dbGetQuery(con, "SELECT * FROM tasks WHERE key = ?", list(idc))
  }
  if (nrow(row) == 0) cli::cli_abort("No task with id {.val {id}}.")
  as.list(row[1, ])
}

# Same id/uuid/key resolution, but against an already-fetched task_list()
# data frame: returns the matching row index per identifier (NA if none),
# so accessors built on task_list() (task_get) accept keys too.
.task_match <- function(ids, df) {
  vapply(ids, function(x) {
    xc <- as.character(x)
    i <- if (grepl("^[0-9]+$", xc)) match(as.integer(xc), df$id)
         else if (grepl(.task_uuid_re, xc)) match(xc, df$uuid)
         else match(xc, df$key)
    as.integer(i)
  }, integer(1))
}

.task_ids_to_uuids <- function(con, ids) {
  vapply(ids, function(i) .task_row(con, i)$uuid, character(1))
}

# Simplified taskwarrior urgency: priority, due proximity, age, tags, and a
# penalty for blocked tasks. `df` must already carry `blocked`.
.task_urgency <- function(df, today = Sys.Date()) {
  if (nrow(df) == 0) return(numeric(0))
  prw  <- c(H = 6, M = 3.9, L = 1.8)
  u_pri <- unname(ifelse(is.na(df$priority), 0, prw[df$priority]))
  u_pri[is.na(u_pri)] <- 0

  days <- as.numeric(suppressWarnings(as.Date(df$due)) - today)
  u_due <- ifelse(is.na(days), 0, ifelse(days < 0, 12,
                  pmax(0, 12 * (14 - pmin(days, 14)) / 14)))

  age <- as.numeric(today - suppressWarnings(as.Date(substr(df$entry, 1, 10))))
  u_age <- ifelse(is.na(age), 0, pmin(2, 2 * age / 365))

  u_tag <- ifelse(is.na(df$tags) | df$tags == "", 0, 1)
  u_blk <- ifelse(df$blocked, -5, 0)
  round(u_pri + u_due + u_age + u_tag + u_blk, 1)
}

# --- exported API -------------------------------------------------------------

#' Create or open a shared task database
#'
#' Initialises a SQLite task database (creating the file and tables if they
#' do not exist) and switches it to WAL mode, so several R processes can
#' read and write the same file concurrently. Safe to call repeatedly.
#'
#' SQLite is free (public domain) and bundled by the `RSQLite` package, so
#' there is no server to run and nothing to license -- a shared `.sqlite`
#' file on a network drive is enough for a team to work from.
#'
#' @param path Path to the `.sqlite` file.
#'
#' @return `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' task_db("tasks.sqlite")
#' }
#'
#' @seealso [daos::task_add()], [daos::task_list()], [daos::task_app()]
#'
#' @importFrom cli cli_abort
#' @export
task_db <- function(path) {
  h <- .task_con(path)
  if (h$close) DBI::dbDisconnect(h$con)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

#' Add a task
#'
#' @param db Path to the task database, or an open DBI connection.
#' @param description The task text (required).
#' @param key Optional user-chosen handle to reference the task by -- a
#'   slug of lowercase letters/digits joined by single `-` or `_` (e.g.
#'   `"compile-accounts"`). Must be unique across the database, and is
#'   accepted anywhere an `id` is. Lets a production script refer to a task
#'   by a stable, readable name instead of a brittle integer. The numeric
#'   `id` and `uuid` keep working regardless.
#' @param project Optional project name.
#' @param assignee Optional person the task is assigned to.
#' @param tags Optional character vector of tags.
#' @param priority Optional priority: `"H"`, `"M"`, or `"L"`.
#' @param due Optional due date (`Date` or `"YYYY-MM-DD"`).
#' @param recur Optional recurrence applied when the task is completed: an
#'   integer number of days, or one of `"daily"`, `"weekly"`,
#'   `"biweekly"`, `"monthly"`, `"quarterly"`, `"semiannual"`, `"yearly"`
#'   -- the cadences statistics production runs on. Needs a `due`.
#' @param depends Optional ids (integer, uuid, or key) this task depends on.
#'
#' @return The new task as a one-row tibble, invisibly.
#'
#' @examples
#' \dontrun{
#' task_add("tasks.sqlite", "Write the report", project = "Q3",
#'          tags = c("writing", "urgent"), priority = "H", due = "2026-07-01")
#'
#' # Give it a key, then refer to it by that key later:
#' task_add("tasks.sqlite", "Compile accounts", key = "compile-accounts")
#' task_done("tasks.sqlite", "compile-accounts")
#' }
#'
#' @seealso [daos::task_list()], [daos::task_done()]
#'
#' @importFrom cli cli_abort
#' @export
task_add <- function(db, description, key = NULL, project = NULL, assignee = NULL,
                     tags = NULL, priority = NULL, due = NULL, recur = NULL,
                     depends = NULL) {
  if (!is.character(description) || length(description) != 1 || !nzchar(description))
    cli::cli_abort("{.arg description} must be a single non-empty string.")
  key      <- .task_check_key(key)
  priority <- .task_check_priority(priority)
  due      <- .task_norm_date(due)

  .task_with_con(db, function(con) {
    uuid <- .task_uuid(); now <- .task_now()
    DBI::dbWithTransaction(con, {
      if (!is.null(key) && nrow(DBI::dbGetQuery(con, "SELECT 1 FROM tasks WHERE key = ?", list(key))) > 0)
        cli::cli_abort("Key {.val {key}} is already in use.")
      DBI::dbExecute(con,
        "INSERT INTO tasks (uuid, key, description, project, assignee, priority, status, due, entry, modified, recur)
         VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)",
        params = list(uuid, .or_na(key), description, .or_na(project), .or_na(assignee),
                      .or_na(priority), .or_na(due), now, now, .or_na(recur)))
      for (tg in unique(tags))
        DBI::dbExecute(con, "INSERT OR IGNORE INTO task_tags (task_uuid, tag) VALUES (?, ?)",
                       params = list(uuid, tg))
      if (length(depends) > 0) {
        for (du in .task_ids_to_uuids(con, depends))
          DBI::dbExecute(con, "INSERT OR IGNORE INTO dependencies (task_uuid, depends_on_uuid) VALUES (?, ?)",
                         params = list(uuid, du))
      }
    })
    invisible(task_list(con, status = "all", .only_uuid = uuid))
  })
}

#' List tasks
#'
#' Returns tasks as a tibble, with tags aggregated, an annotation count, a
#' `blocked` flag (a dependency is still pending), and a simplified
#' taskwarrior `urgency` score. Sorted by urgency by default.
#'
#' @inheritParams task_add
#' @param status Status filter: `"pending"` (default), `"completed"`,
#'   `"deleted"`, `"active"` (pending plus completed, i.e. everything not
#'   soft-deleted), or `"all"`.
#' @param project Optional project filter.
#' @param assignee Optional person filter.
#' @param tag Optional tag filter (kept if the task carries the tag).
#' @param sort One of `"urgency"` (default), `"due"` (forfaldsdato),
#'   `"entry"` (oprettelsesdato), or `"project"`.
#' @param desc If `TRUE`, reverse the sort order (e.g. latest due date or
#'   newest task first). Tasks with no due date or project stay last either
#'   way.
#' @param .only_uuid Internal: restrict to a single uuid.
#'
#' @return A tibble of tasks.
#'
#' @examples
#' \dontrun{
#' task_list("tasks.sqlite")
#' task_list("tasks.sqlite", project = "Q3", tag = "urgent")
#' }
#'
#' @seealso [daos::task_add()], [daos::task_projects()]
#'
#' @importFrom cli cli_abort
#' @importFrom tibble as_tibble
#' @export
task_list <- function(db, status = "pending", project = NULL, assignee = NULL,
                      tag = NULL, sort = c("urgency", "due", "entry", "project"),
                      desc = FALSE, .only_uuid = NULL) {
  sort <- match.arg(sort)
  .task_with_con(db, function(con) {
    where <- character(); params <- list()
    if (identical(status, "active")) {
      # everything that is not soft-deleted -- pending plus completed
      where <- c(where, "t.status IN ('pending','completed')")
    } else if (!identical(status, "all")) {
      where <- c(where, "t.status = ?"); params <- c(params, list(status))
    }
    if (!is.null(project))         { where <- c(where, "t.project = ?");  params <- c(params, list(project)) }
    if (!is.null(assignee))        { where <- c(where, "t.assignee = ?"); params <- c(params, list(assignee)) }
    if (!is.null(.only_uuid))      { where <- c(where, "t.uuid = ?");     params <- c(params, list(.only_uuid)) }

    sql <- paste(
      "SELECT t.id, t.uuid, t.key, t.description, t.project, t.assignee, t.priority, t.status,",
      "       t.due, t.entry, t.modified, t.start, t.end, t.recur,",
      "       (SELECT GROUP_CONCAT(tag, ',') FROM task_tags g WHERE g.task_uuid = t.uuid) AS tags,",
      "       (SELECT COUNT(*) FROM annotations a WHERE a.task_uuid = t.uuid) AS annotations",
      "FROM tasks t")
    if (length(where)) sql <- paste(sql, "WHERE", paste(where, collapse = " AND "))
    df <- if (length(params)) DBI::dbGetQuery(con, sql, params = params)
          else DBI::dbGetQuery(con, sql)

    sm <- DBI::dbGetQuery(con, "SELECT uuid, status FROM tasks")
    status_map <- stats::setNames(sm$status, sm$uuid)
    deps <- DBI::dbGetQuery(con, "SELECT task_uuid, depends_on_uuid FROM dependencies")
    blocked_uuid <- if (nrow(deps) == 0) character(0) else unique(
      deps$task_uuid[!is.na(status_map[deps$depends_on_uuid]) &
                       status_map[deps$depends_on_uuid] == "pending"])
    df$blocked <- df$uuid %in% blocked_uuid
    # In progress: a pending task someone has started (non-NULL start).
    df$started <- !is.na(df$start) & df$status == "pending"
    df$tags[is.na(df$tags)] <- ""
    df$urgency <- .task_urgency(df)

    if (!is.null(tag)) {
      keep <- vapply(strsplit(df$tags, ",", fixed = TRUE),
                     function(ts) tag %in% ts, logical(1))
      df <- df[keep, ]
    }

    # `desc` flips the chosen key (dir applied via xtfrm so it works for the
    # date/text columns too). The is.na() lead term is left ascending, so empty
    # due dates / projects stay grouped at the bottom in both directions rather
    # than jumping to the top when reversed.
    dir <- if (desc) -1 else 1
    due_num <- suppressWarnings(as.numeric(as.Date(df$due)))
    ord <- switch(sort,
      urgency = order(dir * -df$urgency, due_num),
      due     = order(is.na(due_num), dir * due_num, -df$urgency),
      entry   = order(dir * xtfrm(df$entry)),
      project = order(is.na(df$project), dir * xtfrm(df$project), -df$urgency))
    tibble::as_tibble(df[ord, ])
  })
}

#' Get one or more tasks by id
#'
#' Returns the same row [task_list()] would show -- with the `blocked` flag,
#' `urgency`, and annotation count -- for the given id(s). A convenience over
#' filtering [task_list()] by hand when you only want a specific task.
#'
#' @inheritParams task_done
#' @param id One or more task ids -- each an integer id, a uuid, or a key.
#'
#' @return A tibble with one row per id, in the order given.
#'
#' @seealso [task_list()], [task_require()]
#'
#' @importFrom cli cli_abort
#' @export
task_get <- function(db, id) {
  all <- task_list(db, status = "all")
  idx <- .task_match(id, all)
  if (anyNA(idx))
    cli::cli_abort("No task with id {.val {id[is.na(idx)]}}.")
  all[idx, , drop = FALSE]
}

#' Require tasks to have a given status
#'
#' Aborts unless every task in `id` has one of the statuses in `status`
#' (`"completed"` by default). This is a lightweight gate for coordinating a
#' production script: call it before a step that depends on earlier ones
#' being done. It only reads the task database and never touches your data,
#' so it belongs beside the analysis rather than inside it.
#'
#' @inheritParams task_get
#' @param status Allowed status values; each task must be in one of them.
#'
#' @return `id`, invisibly.
#'
#' @seealso [task_get()], [task_done()]
#'
#' @examples
#' \dontrun{
#' task_require(db, 1)            # stop unless task 1 is done
#' task_require(db, c(1, 2))      # ... or several upstream steps
#' }
#'
#' @importFrom cli cli_abort
#' @importFrom glue glue
#' @export
task_require <- function(db, id, status = "completed") {
  row <- task_get(db, id)
  bad <- row[!row$status %in% status, , drop = FALSE]
  if (nrow(bad)) {
    bullets <- as.character(glue::glue("task {bad$id} ({bad$description}) is {bad$status}"))
    names(bullets) <- rep("x", length(bullets))
    cli::cli_abort(c("Task dependency not met -- required status {.val {status}}:", bullets))
  }
  invisible(id)
}

#' Why a task is blocked
#'
#' Returns the prerequisites a task depends on that are not yet completed --
#' the unfinished tasks that make [task_list()] report it as `blocked`. An
#' empty result means nothing is holding it up.
#'
#' @inheritParams task_get
#' @param id A single task identifier: integer id, uuid, or key.
#'
#' @return A tibble with `id`, `uuid`, `description`, and `status` of each
#'   unfinished prerequisite.
#'
#' @seealso [task_list()], [task_require()]
#'
#' @importFrom tibble as_tibble
#' @importFrom cli cli_abort
#' @export
task_blockers <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    tibble::as_tibble(DBI::dbGetQuery(con,
      "SELECT t.id, t.uuid, t.description, t.status
         FROM dependencies d JOIN tasks t ON t.uuid = d.depends_on_uuid
        WHERE d.task_uuid = ? AND t.status = 'pending'
        ORDER BY t.id", params = list(row$uuid)))
  })
}

#' Run a production step under a task
#'
#' Wraps one step of a production script so it both runs and records
#' itself: the task is marked started, `expr` is evaluated, and then -- on
#' success -- annotated and completed; on failure it is annotated with the
#' error, un-started, and the error re-raised. This turns the hand-rolled
#' `run_step()` pattern into one call, so a pipeline leaves a trace of what
#' happened without status code creeping into the analysis.
#'
#' Keep it *beside* the work: `expr` should be the step that produces the
#' result, with the task call wrapping it, not task code woven into a data
#' pipeline.
#'
#' @inheritParams task_done
#' @param expr The step to run. Evaluated once; its value is returned.
#' @param note Optional success note. Defaults to a timestamped `"ok: ..."`.
#'
#' @return The value of `expr`, invisibly. On error, the error is re-raised
#'   after the task is annotated and un-started.
#'
#' @seealso [task_start()], [task_require()], [task_cycle()]
#'
#' @examples
#' \dontrun{
#' task_step(db, "compile-accounts", {
#'   stats <- compile(sources)
#'   stats
#' })
#' }
#'
#' @importFrom cli cli_abort
#' @export
task_step <- function(db, id, expr, note = NULL) {
  task_start(db, id)
  out <- tryCatch(force(expr), error = function(e) e)
  if (inherits(out, "error")) {
    task_annotate(db, id, paste("FAILED:", conditionMessage(out)))
    task_stop(db, id)
    stop(out)
  }
  task_annotate(db, id, if (is.null(note)) paste("ok:", .task_now()) else note)
  task_done(db, id)
  invisible(out)
}

#' Register a production cycle as a chain of steps
#'
#' Adds a sequence of tasks for one statistics production, wired up so each
#' step depends on the one before it. The result is a ready-to-run cycle:
#' [task_list()] reports only the first step as unblocked, and each later
#' step becomes ready as its predecessor is completed. A deadline (and an
#' optional recurrence, so the cycle's release date rolls forward) lands on
#' the final step.
#'
#' @inheritParams task_add
#' @param project The production this cycle belongs to.
#' @param steps Character vector of step descriptions, in order.
#' @param keys Optional character vector of keys, one per step, so the
#'   steps can be referenced by name from scripts.
#' @param due Optional deadline for the *final* step (the release).
#' @param recur Optional recurrence for the final step, so completing the
#'   cycle spawns the next release. See [task_add()] for the cadences.
#'
#' @return A tibble of the created tasks, in order.
#'
#' @seealso [task_step()], [task_require()], [task_add()]
#'
#' @examples
#' \dontrun{
#' task_cycle(db, "RS-2026",
#'   steps = c("Hent kilder", "Validér", "Kompilér", "Publicér"),
#'   keys  = c("hent", "valider", "kompiler", "publicer"),
#'   assignee = "pipeline", due = "2026-07-15", recur = "monthly")
#' }
#'
#' @importFrom cli cli_abort
#' @export
task_cycle <- function(db, project, steps, keys = NULL, assignee = NULL,
                       priority = NULL, due = NULL, recur = NULL) {
  if (!is.character(steps) || length(steps) == 0 || any(!nzchar(steps)))
    cli::cli_abort("{.arg steps} must be a non-empty character vector of step descriptions.")
  if (!is.null(keys) && length(keys) != length(steps))
    cli::cli_abort("{.arg keys} must have one entry per step ({length(steps)}).")
  .task_with_con(db, function(con) {
    ids  <- integer(length(steps))
    prev <- NULL
    for (i in seq_along(steps)) {
      last <- i == length(steps)
      t <- task_add(con, steps[i], key = if (!is.null(keys)) keys[i] else NULL,
                    project = project, assignee = assignee, priority = priority,
                    due = if (last) due else NULL, recur = if (last) recur else NULL,
                    depends = prev)
      ids[i] <- t$id[1]
      prev   <- t$id[1]
    }
    task_get(con, ids)
  })
}

#' Complete a task
#'
#' Marks the task completed. If it has a recurrence and a due date, the next
#' instance is created automatically with the due date advanced (tags are
#' carried over). This is a simplified recurrence model -- one instance is
#' spawned per completion.
#'
#' @inheritParams task_add
#' @param id Task identifier: the integer id, the uuid, or the key.
#' @param note Optional note to attach as the task is completed, so a step
#'   can be closed with a one-line annotation instead of a separate
#'   [task_annotate()] call.
#'
#' @return `TRUE`, invisibly.
#'
#' @seealso [daos::task_add()], [daos::task_delete()]
#'
#' @importFrom cli cli_abort
#' @export
task_done <- function(db, id, note = NULL) {
  if (!is.null(note) && (!is.character(note) || length(note) != 1 || !nzchar(note)))
    cli::cli_abort("{.arg note} must be a single non-empty string.")
  .task_with_con(db, function(con) {
    row <- .task_row(con, id); now <- .task_now()
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, "UPDATE tasks SET status='completed', end=?, modified=? WHERE id=?",
                     params = list(now, now, row$id))
      if (!is.null(note))
        DBI::dbExecute(con, "INSERT INTO annotations (task_uuid, entry, text) VALUES (?, ?, ?)",
                       params = list(row$uuid, now, note))
      if (!is.na(row$recur) && nzchar(row$recur) && !is.na(row$due)) {
        nuuid <- .task_uuid()
        DBI::dbExecute(con,
          "INSERT INTO tasks (uuid, description, project, priority, status, due, entry, modified, recur)
           VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?)",
          params = list(nuuid, row$description, .or_na(row$project), .or_na(row$priority),
                        .task_advance(row$due, row$recur), now, now, row$recur))
        for (tg in DBI::dbGetQuery(con, "SELECT tag FROM task_tags WHERE task_uuid=?",
                                   params = list(row$uuid))$tag)
          DBI::dbExecute(con, "INSERT OR IGNORE INTO task_tags (task_uuid, tag) VALUES (?, ?)",
                         params = list(nuuid, tg))
      }
    })
    invisible(TRUE)
  })
}

#' Reopen a task
#'
#' Sets a completed or deleted task back to pending and clears its end
#' time -- the undo for [daos::task_done()] and [daos::task_delete()].
#'
#' @inheritParams task_done
#'
#' @return `TRUE`, invisibly.
#'
#' @importFrom cli cli_abort
#' @export
task_reopen <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    DBI::dbExecute(con, "UPDATE tasks SET status='pending', end=NULL, start=NULL, modified=? WHERE id=?",
                   params = list(.task_now(), row$id))
    invisible(TRUE)
  })
}

#' Start or stop work on a task
#'
#' `task_start()` marks a pending task as in progress by stamping it with a
#' start time; `task_stop()` clears that stamp. A started task stays
#' `pending` -- "in progress" is a flag, not a separate status -- and
#' [task_list()] reports it through the `started` column. This is what lets
#' the overview show *what is being worked on right now*, not just what is
#' pending, so a production step can announce itself when it begins:
#' `task_start(db, "compile-accounts")` at the top of the step, beside the
#' work rather than inside it.
#'
#' @inheritParams task_done
#'
#' @return `TRUE`, invisibly.
#'
#' @seealso [task_step()], [task_done()], [task_list()]
#'
#' @examples
#' \dontrun{
#' task_start(db, "compile-accounts")   # now shown as in progress
#' task_stop(db, "compile-accounts")    # back to plain pending
#' }
#'
#' @importFrom cli cli_abort
#' @export
task_start <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    if (!identical(row$status, "pending"))
      cli::cli_abort("Only a pending task can be started (task {.val {id}} is {row$status}).")
    now <- .task_now()
    DBI::dbExecute(con, "UPDATE tasks SET start=?, modified=? WHERE id=?",
                   params = list(now, now, row$id))
    invisible(TRUE)
  })
}

#' @rdname task_start
#' @export
task_stop <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    DBI::dbExecute(con, "UPDATE tasks SET start=NULL, modified=? WHERE id=?",
                   params = list(.task_now(), row$id))
    invisible(TRUE)
  })
}

#' Delete a task
#'
#' Marks the task deleted (it is kept in the database, not removed).
#'
#' @inheritParams task_done
#'
#' @return `TRUE`, invisibly.
#'
#' @importFrom cli cli_abort
#' @export
task_delete <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id); now <- .task_now()
    DBI::dbExecute(con, "UPDATE tasks SET status='deleted', end=?, modified=? WHERE id=?",
                   params = list(now, now, row$id))
    invisible(TRUE)
  })
}

#' Permanently delete tasks
#'
#' Removes tasks from the database for good -- together with their tags,
#' annotations, and dependency links. Where [task_delete()] only marks a task
#' `deleted` so it can still be reopened, this is the hard delete that empties
#' the trash, and it cannot be undone.
#'
#' @inheritParams task_done
#' @param id Tasks to purge: integer id, uuid, or key. If `NULL` (default),
#'   every soft-deleted task is removed -- i.e. empty the trash.
#'
#' @return The number of tasks purged, invisibly.
#'
#' @seealso [daos::task_delete()], [daos::task_reopen()]
#'
#' @importFrom cli cli_abort
#' @export
task_purge <- function(db, id = NULL) {
  .task_with_con(db, function(con) {
    uuids <- if (is.null(id)) {
      DBI::dbGetQuery(con, "SELECT uuid FROM tasks WHERE status='deleted'")$uuid
    } else {
      vapply(id, function(i) .task_row(con, i)$uuid, character(1))
    }
    uuids <- unname(uuids)                 # vapply over a character id names the result
    if (length(uuids) == 0) return(invisible(0L))
    ph <- paste(rep("?", length(uuids)), collapse = ",")
    u  <- as.list(uuids)
    DBI::dbWithTransaction(con, {
      DBI::dbExecute(con, paste0("DELETE FROM task_tags WHERE task_uuid IN (", ph, ")"), params = u)
      DBI::dbExecute(con, paste0("DELETE FROM annotations WHERE task_uuid IN (", ph, ")"), params = u)
      DBI::dbExecute(con, paste0("DELETE FROM dependencies WHERE task_uuid IN (", ph,
                                 ") OR depends_on_uuid IN (", ph, ")"), params = c(u, u))
      DBI::dbExecute(con, paste0("DELETE FROM tasks WHERE uuid IN (", ph, ")"), params = u)
    })
    invisible(length(uuids))
  })
}

#' Modify a task
#'
#' Updates the supplied fields. Pass `tags` to replace the task's tags.
#'
#' @inheritParams task_add
#' @param id Task identifier: the integer id, the uuid, or the key.
#'
#' @details Pass `key` to set or rename the task's key; pass `key = ""` to
#'   remove it. A new key must still be unique. Pass `tags` or `depends` to
#'   *replace* the task's tags or its dependencies (use `character(0)` to
#'   clear them); pass `recur = ""` to stop a task recurring.
#'
#' @return `TRUE`, invisibly.
#'
#' @importFrom cli cli_abort
#' @export
task_modify <- function(db, id, description = NULL, key = NULL, project = NULL,
                        assignee = NULL, tags = NULL, priority = NULL, due = NULL,
                        recur = NULL, depends = NULL) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id); now <- .task_now()

    sets <- character(); params <- list()
    if (!is.null(description)) { sets <- c(sets, "description=?"); params <- c(params, list(description)) }
    if (!is.null(key)) {
      if (is.character(key) && length(key) == 1 && !nzchar(trimws(key))) {
        sets <- c(sets, "key=?"); params <- c(params, list(NA))      # "" clears it
      } else {
        k <- .task_check_key(key)
        if (nrow(DBI::dbGetQuery(con, "SELECT 1 FROM tasks WHERE key = ? AND id <> ?", list(k, row$id))) > 0)
          cli::cli_abort("Key {.val {k}} is already in use.")
        sets <- c(sets, "key=?"); params <- c(params, list(k))
      }
    }
    if (!is.null(project))     { sets <- c(sets, "project=?");     params <- c(params, list(.or_na(project))) }
    if (!is.null(assignee))    { sets <- c(sets, "assignee=?");    params <- c(params, list(.or_na(assignee))) }
    if (!is.null(priority))    { sets <- c(sets, "priority=?");    params <- c(params, list(.task_check_priority(priority))) }
    if (!is.null(due))         { sets <- c(sets, "due=?");         params <- c(params, list(.task_norm_date(due))) }
    if (!is.null(recur))       { sets <- c(sets, "recur=?");       params <- c(params, list(if (nzchar(recur)) recur else NA)) }

    DBI::dbWithTransaction(con, {
      if (length(sets) > 0) {
        sets <- c(sets, "modified=?"); params <- c(params, list(now), list(row$id))
        DBI::dbExecute(con, paste0("UPDATE tasks SET ", paste(sets, collapse = ", "), " WHERE id=?"),
                       params = params)
      }
      if (!is.null(tags)) {
        DBI::dbExecute(con, "DELETE FROM task_tags WHERE task_uuid=?", params = list(row$uuid))
        for (tg in unique(tags))
          DBI::dbExecute(con, "INSERT OR IGNORE INTO task_tags (task_uuid, tag) VALUES (?, ?)",
                         params = list(row$uuid, tg))
      }
      # Replace the task's dependencies. character(0) just clears them. A task
      # may not depend on itself.
      if (!is.null(depends)) {
        DBI::dbExecute(con, "DELETE FROM dependencies WHERE task_uuid=?", params = list(row$uuid))
        for (du in setdiff(.task_ids_to_uuids(con, depends), row$uuid))
          DBI::dbExecute(con, "INSERT OR IGNORE INTO dependencies (task_uuid, depends_on_uuid) VALUES (?, ?)",
                         params = list(row$uuid, du))
      }
    })
    invisible(TRUE)
  })
}

#' Annotate a task
#'
#' Adds a timestamped note to a task.
#'
#' @inheritParams task_done
#' @param text The annotation text.
#'
#' @return `TRUE`, invisibly.
#'
#' @importFrom cli cli_abort
#' @export
task_annotate <- function(db, id, text) {
  if (!is.character(text) || length(text) != 1 || !nzchar(text))
    cli::cli_abort("{.arg text} must be a single non-empty string.")
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    DBI::dbExecute(con, "INSERT INTO annotations (task_uuid, entry, text) VALUES (?, ?, ?)",
                   params = list(row$uuid, .task_now(), text))
    invisible(TRUE)
  })
}

#' Annotations of a task
#'
#' @inheritParams task_done
#'
#' @return A tibble with `entry` and `text`.
#'
#' @importFrom tibble as_tibble
#' @export
task_annotations <- function(db, id) {
  .task_with_con(db, function(con) {
    row <- .task_row(con, id)
    tibble::as_tibble(DBI::dbGetQuery(con,
      "SELECT entry, text FROM annotations WHERE task_uuid=? ORDER BY entry", params = list(row$uuid)))
  })
}

# Per-group counts: sum a logical mask over a grouping factor, aligned to
# `levels`. NA-safe and always integer.
.task_agg <- function(mask, by, levels) {
  out <- tapply(as.integer(mask), by, sum)
  v <- as.integer(out[levels]); v[is.na(v)] <- 0L; v
}

#' Project overview for managers
#'
#' One row per project, built for a quick read of where each production
#' stands: a health signal, how much is pending, in progress, blocked,
#' done and overdue, how much has stalled, the next deadline, and the
#' first/last activity. Designed so a lead can scan it and see what is on
#' track and where the bottlenecks are.
#'
#' @inheritParams task_add
#' @param stale_days A pending task untouched for more than this many days
#'   (and neither started nor blocked) counts as stalled. Default 14.
#'
#' @return A tibble, one row per project, with `project`, `health`
#'   (`"green"`, `"amber"`, `"red"`, or `"done"`), `pending`, `started`,
#'   `blocked`, `completed`, `total`, `pct_done`, `overdue`, `stalled`,
#'   `next_due` (a `Date`), `days_to_due`, `created`, and `last_activity`.
#'   Health is `red` with any overdue task, `amber` with a blocker, a
#'   stalled task or a deadline within a week, `green` otherwise, and
#'   `done` when nothing is pending.
#'
#' @seealso [task_bottlenecks()], [task_people()], [task_activity()]
#'
#' @importFrom tibble as_tibble tibble
#' @export
task_projects <- function(db, stale_days = 14) {
  at    <- task_list(db, status = "active")
  today <- Sys.Date()
  empty <- tibble::tibble(
    project = character(), health = character(), pending = integer(),
    started = integer(), blocked = integer(), completed = integer(),
    total = integer(), pct_done = numeric(), overdue = integer(),
    stalled = integer(), next_due = as.Date(character()),
    days_to_due = numeric(), created = character(), last_activity = character())
  if (nrow(at) == 0) return(empty)

  pk   <- ifelse(is.na(at$project) | !nzchar(at$project), "(intet projekt)", at$project)
  due  <- suppressWarnings(as.Date(at$due))
  mod  <- suppressWarnings(as.Date(substr(at$modified, 1, 10)))
  pend <- at$status == "pending"
  comp <- at$status == "completed"
  overdue_row <- pend & !is.na(due) & due < today
  stalled_row <- pend & !at$started & !at$blocked &
                 !is.na(mod) & as.numeric(today - mod) > stale_days
  projs <- sort(unique(pk))

  pending_n   <- .task_agg(pend, pk, projs)
  completed_n <- .task_agg(comp, pk, projs)
  started_n   <- .task_agg(pend & at$started, pk, projs)
  blocked_n   <- .task_agg(pend & at$blocked, pk, projs)
  overdue_n   <- .task_agg(overdue_row, pk, projs)
  stalled_n   <- .task_agg(stalled_row, pk, projs)

  nd <- tapply(ifelse(pend & !is.na(due), as.numeric(due), NA), pk,
               function(x) suppressWarnings(min(x, na.rm = TRUE)))[projs]
  nd[is.infinite(nd)] <- NA
  next_due <- as.Date(unname(nd), origin = "1970-01-01")
  days_to  <- as.numeric(next_due - today)

  created  <- unname(tapply(substr(at$entry, 1, 10),   pk, min)[projs])
  last_act <- unname(tapply(substr(at$modified, 1, 10), pk, max)[projs])
  total    <- pending_n + completed_n
  pct      <- ifelse(total == 0, 0, round(100 * completed_n / total))
  health   <- vapply(seq_along(projs), function(i) {
    if (pending_n[i] == 0) "done"
    else if (overdue_n[i] > 0) "red"
    else if (blocked_n[i] > 0 || stalled_n[i] > 0 ||
             (!is.na(days_to[i]) && days_to[i] <= 7)) "amber"
    else "green"
  }, character(1))

  tibble::tibble(
    project = projs, health = health, pending = pending_n, started = started_n,
    blocked = blocked_n, completed = completed_n, total = total, pct_done = pct,
    overdue = overdue_n, stalled = stalled_n, next_due = next_due,
    days_to_due = days_to, created = created, last_activity = last_act)
}

#' People overview
#'
#' One row per assignee with their current load: pending, in progress,
#' blocked and overdue tasks, how many they have completed in the last 30
#' days, and across how many projects -- enough to spot who is overloaded
#' or where a person has become a bottleneck.
#'
#' @inheritParams task_add
#'
#' @return A tibble with `assignee`, `pending`, `started`, `blocked`,
#'   `overdue`, `done30`, and `projects`.
#'
#' @seealso [task_projects()], [task_bottlenecks()]
#'
#' @importFrom tibble as_tibble tibble
#' @export
task_people <- function(db) {
  at <- task_list(db, status = "active")
  at <- at[!is.na(at$assignee) & nzchar(at$assignee), ]
  empty <- tibble::tibble(
    assignee = character(), pending = integer(), started = integer(),
    blocked = integer(), overdue = integer(), done30 = integer(),
    projects = integer())
  if (nrow(at) == 0) return(empty)

  today  <- Sys.Date()
  due    <- suppressWarnings(as.Date(at$due))
  endd   <- suppressWarnings(as.Date(substr(at$end, 1, 10)))
  pend   <- at$status == "pending"
  people <- sort(unique(at$assignee))

  tibble::tibble(
    assignee = people,
    pending  = .task_agg(pend, at$assignee, people),
    started  = .task_agg(pend & at$started, at$assignee, people),
    blocked  = .task_agg(pend & at$blocked, at$assignee, people),
    overdue  = .task_agg(pend & !is.na(due) & due < today, at$assignee, people),
    done30   = .task_agg(at$status == "completed" & !is.na(endd) &
                           as.numeric(today - endd) <= 30, at$assignee, people),
    projects = vapply(people, function(p) {
      pr <- at$project[pend & at$assignee == p]
      length(unique(pr[!is.na(pr) & nzchar(pr)]))
    }, integer(1)))
}

#' Bottlenecks: the tasks blocking the most others
#'
#' The unfinished prerequisites that hold up the most downstream work --
#' the real bottlenecks. Each row is a pending task that one or more other
#' pending tasks depend on, ranked by how many it blocks, so a lead can see
#' which single task to unblock first.
#'
#' @inheritParams task_add
#'
#' @return A tibble with `id`, `key`, `description`, `project`, `assignee`,
#'   and `blocking` (the number of pending tasks waiting on it), most
#'   blocking first. Empty when nothing is blocked.
#'
#' @seealso [task_blockers()], [task_projects()]
#'
#' @importFrom tibble as_tibble
#' @export
task_bottlenecks <- function(db) {
  .task_with_con(db, function(con) {
    tibble::as_tibble(DBI::dbGetQuery(con,
      "SELECT t.id, t.key, t.description, t.project, t.assignee,
              COUNT(*) AS blocking
         FROM dependencies d
         JOIN tasks t  ON t.uuid = d.depends_on_uuid
         JOIN tasks bt ON bt.uuid = d.task_uuid
        WHERE t.status = 'pending' AND bt.status = 'pending'
        GROUP BY t.uuid
        ORDER BY blocking DESC, t.id"))
  })
}

#' Recent activity across the database
#'
#' A merged, newest-first feed of what has happened: tasks added,
#' completed, and annotated. Gives a manager a glance at what is moving
#' without opening individual tasks.
#'
#' @inheritParams task_add
#' @param n Maximum number of events to return. Default 20.
#'
#' @return A tibble with `ts` (timestamp), `kind` (`"added"`, `"done"`, or
#'   `"note"`), `id`, `description`, `project`, and `text` (the note, else
#'   `NA`), most recent first.
#'
#' @seealso [task_projects()], [task_annotations()]
#'
#' @importFrom tibble as_tibble
#' @export
task_activity <- function(db, n = 20) {
  .task_with_con(db, function(con) {
    q <- DBI::dbGetQuery(con,
      "SELECT a.entry AS ts, 'note' AS kind, t.id, t.description, t.project, a.text
         FROM annotations a JOIN tasks t ON t.uuid = a.task_uuid
       UNION ALL
       SELECT t.end AS ts, 'done' AS kind, t.id, t.description, t.project, NULL AS text
         FROM tasks t WHERE t.status = 'completed' AND t.end IS NOT NULL
       UNION ALL
       SELECT t.entry AS ts, 'added' AS kind, t.id, t.description, t.project, NULL AS text
         FROM tasks t
       ORDER BY ts DESC")
    if (nrow(q) > n) q <- q[seq_len(n), , drop = FALSE]
    tibble::as_tibble(q)
  })
}
