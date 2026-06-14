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

# Create the schema only if it is missing, and add the assignee column to
# older databases. In steady state this is a single read (PRAGMA), so
# concurrent connections do not contend on DDL write locks.
.task_ensure <- function(con) {
  cols <- DBI::dbGetQuery(con, "PRAGMA table_info(tasks)")$name
  if (length(cols) == 0) { .task_schema(con); return(invisible(TRUE)) }
  if (!"assignee" %in% cols)
    DBI::dbExecute(con, "ALTER TABLE tasks ADD COLUMN assignee TEXT")
  invisible(TRUE)
}

.task_schema <- function(con) {
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    project TEXT,
    assignee TEXT,
    priority TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    due TEXT,
    entry TEXT NOT NULL,
    modified TEXT NOT NULL,
    end TEXT,
    recur TEXT
  );")
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

.or_na <- function(x) if (is.null(x) || length(x) == 0) NA else x

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
# daily/weekly/biweekly/monthly/quarterly/yearly.
.task_advance <- function(due, recur) {
  d <- as.Date(due)
  r <- tolower(trimws(recur))
  n <- suppressWarnings(as.integer(r))
  out <- if (!is.na(n)) d + n else switch(
    r,
    daily = d + 1, weekly = d + 7, biweekly = d + 14,
    monthly = seq(d, by = "month", length.out = 2)[2],
    quarterly = seq(d, by = "3 months", length.out = 2)[2],
    yearly = , annually = seq(d, by = "year", length.out = 2)[2],
    d + 7
  )
  format(out, "%Y-%m-%d")
}

.task_row <- function(con, id) {
  if (is.numeric(id) || grepl("^[0-9]+$", as.character(id))) {
    row <- DBI::dbGetQuery(con, "SELECT * FROM tasks WHERE id = ?", list(as.integer(id)))
  } else {
    row <- DBI::dbGetQuery(con, "SELECT * FROM tasks WHERE uuid = ?", list(as.character(id)))
  }
  if (nrow(row) == 0) cli::cli_abort("No task with id {.val {id}}.")
  as.list(row[1, ])
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
#' @param project Optional project name.
#' @param assignee Optional person the task is assigned to.
#' @param tags Optional character vector of tags.
#' @param priority Optional priority: `"H"`, `"M"`, or `"L"`.
#' @param due Optional due date (`Date` or `"YYYY-MM-DD"`).
#' @param recur Optional recurrence applied when the task is completed: an
#'   integer number of days, or one of `"daily"`, `"weekly"`,
#'   `"biweekly"`, `"monthly"`, `"quarterly"`, `"yearly"`. Needs a `due`.
#' @param depends Optional ids (integer or uuid) this task depends on.
#'
#' @return The new task as a one-row tibble, invisibly.
#'
#' @examples
#' \dontrun{
#' task_add("tasks.sqlite", "Write the report", project = "Q3",
#'          tags = c("writing", "urgent"), priority = "H", due = "2026-07-01")
#' }
#'
#' @seealso [daos::task_list()], [daos::task_done()]
#'
#' @importFrom cli cli_abort
#' @export
task_add <- function(db, description, project = NULL, assignee = NULL, tags = NULL,
                     priority = NULL, due = NULL, recur = NULL, depends = NULL) {
  if (!is.character(description) || length(description) != 1 || !nzchar(description))
    cli::cli_abort("{.arg description} must be a single non-empty string.")
  priority <- .task_check_priority(priority)
  due      <- .task_norm_date(due)

  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  uuid <- .task_uuid(); now <- .task_now()

  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con,
      "INSERT INTO tasks (uuid, description, project, assignee, priority, status, due, entry, modified, recur)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)",
      params = list(uuid, description, .or_na(project), .or_na(assignee), .or_na(priority),
                    .or_na(due), now, now, .or_na(recur)))
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
}

#' List tasks
#'
#' Returns tasks as a tibble, with tags aggregated, an annotation count, a
#' `blocked` flag (a dependency is still pending), and a simplified
#' taskwarrior `urgency` score. Sorted by urgency by default.
#'
#' @inheritParams task_add
#' @param status Status filter: `"pending"` (default), `"completed"`,
#'   `"deleted"`, or `"all"`.
#' @param project Optional project filter.
#' @param assignee Optional person filter.
#' @param tag Optional tag filter (kept if the task carries the tag).
#' @param sort One of `"urgency"` (default), `"due"`, `"entry"`,
#'   `"project"`.
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
                      .only_uuid = NULL) {
  sort <- match.arg(sort)
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))

  where <- character(); params <- list()
  if (!identical(status, "all")) { where <- c(where, "t.status = ?");   params <- c(params, list(status)) }
  if (!is.null(project))         { where <- c(where, "t.project = ?");  params <- c(params, list(project)) }
  if (!is.null(assignee))        { where <- c(where, "t.assignee = ?"); params <- c(params, list(assignee)) }
  if (!is.null(.only_uuid))      { where <- c(where, "t.uuid = ?");     params <- c(params, list(.only_uuid)) }

  sql <- paste(
    "SELECT t.id, t.uuid, t.description, t.project, t.assignee, t.priority, t.status,",
    "       t.due, t.entry, t.modified, t.end, t.recur,",
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
  df$tags[is.na(df$tags)] <- ""
  df$urgency <- .task_urgency(df)

  if (!is.null(tag)) {
    keep <- vapply(strsplit(df$tags, ",", fixed = TRUE),
                   function(ts) tag %in% ts, logical(1))
    df <- df[keep, ]
  }

  ord <- switch(sort,
    urgency = order(-df$urgency, df$due),
    due     = order(is.na(df$due), df$due, -df$urgency),
    entry   = order(df$entry),
    project = order(is.na(df$project), df$project, -df$urgency))
  tibble::as_tibble(df[ord, ])
}

#' Get one or more tasks by id
#'
#' Returns the same row [task_list()] would show -- with the `blocked` flag,
#' `urgency`, and annotation count -- for the given id(s). A convenience over
#' filtering [task_list()] by hand when you only want a specific task.
#'
#' @inheritParams task_done
#' @param id One or more task ids (the small integers).
#'
#' @return A tibble with one row per id, in the order given.
#'
#' @seealso [task_list()], [task_require()]
#'
#' @importFrom cli cli_abort
#' @export
task_get <- function(db, id) {
  all <- task_list(db, status = "all")
  missing <- setdiff(id, all$id)
  if (length(missing))
    cli::cli_abort("No task with id {.val {missing}}.")
  all[match(id, all$id), , drop = FALSE]
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

#' Complete a task
#'
#' Marks the task completed. If it has a recurrence and a due date, the next
#' instance is created automatically with the due date advanced (tags are
#' carried over). This is a simplified recurrence model -- one instance is
#' spawned per completion.
#'
#' @inheritParams task_add
#' @param id Task id (the small integer) or uuid.
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
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
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
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  row <- .task_row(con, id)
  DBI::dbExecute(con, "UPDATE tasks SET status='pending', end=NULL, modified=? WHERE id=?",
                 params = list(.task_now(), row$id))
  invisible(TRUE)
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
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  row <- .task_row(con, id); now <- .task_now()
  DBI::dbExecute(con, "UPDATE tasks SET status='deleted', end=?, modified=? WHERE id=?",
                 params = list(now, now, row$id))
  invisible(TRUE)
}

#' Modify a task
#'
#' Updates the supplied fields. Pass `tags` to replace the task's tags.
#'
#' @inheritParams task_add
#' @param id Task id (integer) or uuid.
#'
#' @return `TRUE`, invisibly.
#'
#' @importFrom cli cli_abort
#' @export
task_modify <- function(db, id, description = NULL, project = NULL, assignee = NULL,
                        tags = NULL, priority = NULL, due = NULL, recur = NULL) {
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  row <- .task_row(con, id); now <- .task_now()

  sets <- character(); params <- list()
  if (!is.null(description)) { sets <- c(sets, "description=?"); params <- c(params, list(description)) }
  if (!is.null(project))     { sets <- c(sets, "project=?");     params <- c(params, list(.or_na(project))) }
  if (!is.null(assignee))    { sets <- c(sets, "assignee=?");    params <- c(params, list(.or_na(assignee))) }
  if (!is.null(priority))    { sets <- c(sets, "priority=?");    params <- c(params, list(.task_check_priority(priority))) }
  if (!is.null(due))         { sets <- c(sets, "due=?");         params <- c(params, list(.task_norm_date(due))) }
  if (!is.null(recur))       { sets <- c(sets, "recur=?");       params <- c(params, list(recur)) }

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
  })
  invisible(TRUE)
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
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  row <- .task_row(con, id)
  DBI::dbExecute(con, "INSERT INTO annotations (task_uuid, entry, text) VALUES (?, ?, ?)",
                 params = list(row$uuid, .task_now(), text))
  invisible(TRUE)
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
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  row <- .task_row(con, id)
  tibble::as_tibble(DBI::dbGetQuery(con,
    "SELECT entry, text FROM annotations WHERE task_uuid=? ORDER BY entry", params = list(row$uuid)))
}

#' Project overview
#'
#' One row per project with pending/completed/total counts, completion
#' percentage, the number of overdue pending tasks, the project's start
#' (earliest task creation) and the most recent activity.
#'
#' @inheritParams task_add
#'
#' @return A tibble with `project`, `pending`, `completed`, `total`,
#'   `pct_done`, `overdue`, `created`, `last_activity`.
#'
#' @importFrom tibble as_tibble
#' @export
task_projects <- function(db) {
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  df <- DBI::dbGetQuery(con,
    "SELECT COALESCE(project, '(intet projekt)') AS project,
            SUM(status = 'pending')   AS pending,
            SUM(status = 'completed') AS completed,
            SUM(status = 'pending' AND due IS NOT NULL AND due < date('now')) AS overdue,
            MIN(entry)    AS created,
            MAX(modified) AS last_activity
     FROM tasks WHERE status IN ('pending','completed')
     GROUP BY COALESCE(project, '(intet projekt)')
     ORDER BY project")
  if (nrow(df) == 0)
    return(tibble::tibble(project = character(), pending = integer(),
                          completed = integer(), total = integer(),
                          pct_done = numeric(), overdue = integer(),
                          created = character(), last_activity = character()))
  df$total    <- df$pending + df$completed
  df$pct_done <- ifelse(df$total == 0, 0, round(100 * df$completed / df$total))
  df$created       <- substr(df$created, 1, 10)
  df$last_activity <- substr(df$last_activity, 1, 10)
  tibble::as_tibble(df[, c("project", "pending", "completed", "total",
                           "pct_done", "overdue", "created", "last_activity")])
}

#' People overview
#'
#' Distinct assignees with their pending task counts.
#'
#' @inheritParams task_add
#'
#' @return A tibble with `assignee` and `pending`.
#'
#' @importFrom tibble as_tibble
#' @export
task_people <- function(db) {
  h <- .task_con(db); con <- h$con
  on.exit(if (h$close) DBI::dbDisconnect(con))
  tibble::as_tibble(DBI::dbGetQuery(con,
    "SELECT assignee, COUNT(*) AS pending FROM tasks
     WHERE status='pending' AND assignee IS NOT NULL AND assignee <> ''
     GROUP BY assignee ORDER BY assignee"))
}
