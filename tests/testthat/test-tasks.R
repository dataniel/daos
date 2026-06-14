skip_if_not_installed("RSQLite")
skip_if_not_installed("DBI")

tmp_db <- function() tempfile(fileext = ".sqlite")

test_that("task_db creates the schema and is idempotent", {
  db <- tmp_db(); on.exit(unlink(db))
  task_db(db)
  task_db(db)  # again -- should not error
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tbls <- DBI::dbListTables(con)
  expect_true(all(c("tasks", "task_tags", "annotations", "dependencies") %in% tbls))
})

test_that("task_add inserts and task_list returns it", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Write report", project = "Q3", tags = c("writing", "urgent"),
           priority = "H", due = format(Sys.Date() + 3, "%Y-%m-%d"))
  out <- task_list(db)
  expect_equal(nrow(out), 1)
  expect_equal(out$description, "Write report")
  expect_equal(out$project, "Q3")
  expect_equal(out$priority, "H")
  expect_true(grepl("writing", out$tags) && grepl("urgent", out$tags))
  expect_equal(out$status, "pending")
})

test_that("task_list filters by project, tag, and status", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "A", project = "X", tags = "red")
  task_add(db, "B", project = "Y", tags = "blue")
  expect_equal(task_list(db, project = "X")$description, "A")
  expect_equal(task_list(db, tag = "blue")$description, "B")
  expect_equal(nrow(task_list(db, status = "completed")), 0)
})

test_that("assignee is stored, filtered, and summarised", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "A", assignee = "Anna")
  task_add(db, "B", assignee = "Bo")
  task_add(db, "C", assignee = "Anna")
  expect_equal(task_list(db, assignee = "Anna")$description, c("A", "C"))
  ppl <- task_people(db)
  expect_equal(ppl$pending[ppl$assignee == "Anna"], 2)
})

test_that("task_done completes and respects recurrence", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Weekly review", recur = "weekly",
           due = format(Sys.Date(), "%Y-%m-%d"))
  id <- task_list(db)$id[1]
  task_done(db, id)
  pend <- task_list(db, status = "pending")
  done <- task_list(db, status = "completed")
  expect_equal(nrow(done), 1)
  expect_equal(nrow(pend), 1)                       # next instance spawned
  expect_equal(pend$due, format(Sys.Date() + 7, "%Y-%m-%d"))
})

test_that("task_done without recurrence does not spawn", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "One-off")
  task_done(db, task_list(db)$id[1])
  expect_equal(nrow(task_list(db, status = "pending")), 0)
})

test_that("task_reopen undoes completion", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Reopen me")
  id <- task_list(db)$id[1]
  task_done(db, id)
  expect_equal(nrow(task_list(db, status = "pending")), 0)
  task_reopen(db, id)
  expect_equal(nrow(task_list(db, status = "pending")), 1)
  expect_equal(nrow(task_list(db, status = "completed")), 0)
})

test_that("dependencies mark a task as blocked", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "First")
  id1 <- task_list(db)$id[1]
  task_add(db, "Second", depends = id1)
  lst <- task_list(db)
  second <- lst[lst$description == "Second", ]
  first  <- lst[lst$description == "First", ]
  expect_true(second$blocked)
  expect_false(first$blocked)
  # Completing the blocker unblocks the dependent
  task_done(db, id1)
  again <- task_list(db)
  expect_false(again$blocked[again$description == "Second"])
})

test_that("annotations round-trip", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Has notes")
  id <- task_list(db)$id[1]
  task_annotate(db, id, "first note")
  task_annotate(db, id, "second note")
  ann <- task_annotations(db, id)
  expect_equal(nrow(ann), 2)
  expect_equal(ann$text, c("first note", "second note"))
  expect_equal(task_list(db)$annotations[1], 2)
})

test_that("task_get returns rows by id in order", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "One"); task_add(db, "Two"); task_add(db, "Three")
  got <- task_get(db, c(3, 1))
  expect_equal(got$description, c("Three", "One"))
  expect_error(task_get(db, 99), "No task with id")
})

test_that("task_require gates on status", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Upstream"); task_add(db, "Downstream")
  expect_error(task_require(db, 1), "dependency not met")
  task_done(db, 1)
  expect_equal(task_require(db, 1), 1)             # passes, returns id
  expect_error(task_require(db, c(1, 2)), "Downstream")  # one still pending
})

test_that("task_blockers lists the unfinished prerequisites", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "A"); task_add(db, "B")
  task_add(db, "C", depends = c(1, 2))   # id 3 waits on 1 and 2
  expect_equal(sort(task_blockers(db, 3)$description), c("A", "B"))
  task_done(db, 1)
  expect_equal(task_blockers(db, 3)$description, "B")   # A no longer blocks
  task_done(db, 2)
  expect_equal(nrow(task_blockers(db, 3)), 0)           # nothing left
  expect_false(task_list(db)$blocked[task_list(db)$id == 3])
})

test_that("task_done attaches an optional note", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "With closing note")
  task_done(db, 1, note = "done and noted")
  expect_equal(task_annotations(db, 1)$text, "done and noted")
  expect_equal(task_get(db, 1)$status, "completed")
})

test_that("deleted tasks are hidden from active but shown under deleted", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "keep"); task_add(db, "trash")
  task_delete(db, task_list(db)$id[task_list(db)$description == "trash"])
  expect_equal(task_list(db, status = "pending")$description, "keep")
  expect_equal(task_list(db, status = "active")$description, "keep")   # not deleted
  expect_equal(nrow(task_list(db, status = "all")), 2)                 # all includes it
  expect_equal(task_list(db, status = "deleted")$description, "trash")
})

test_that("task_purge hard-deletes the trash and cleans up related rows", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "a", key = "a", tags = "x")
  task_add(db, "b", key = "b", depends = "a")
  task_annotate(db, "a", "note on a")
  task_delete(db, "a"); task_delete(db, "b")

  expect_equal(task_purge(db), 2L)                       # empties the trash
  expect_equal(nrow(task_list(db, status = "all")), 0)
  # tags, annotations, and dependency links went with them
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM task_tags")$n, 0)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM annotations")$n, 0)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dependencies")$n, 0)
})

test_that("task_purge targets specific tasks and leaves the rest", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "one", key = "one"); task_add(db, "two")
  task_delete(db, "one")
  expect_equal(task_purge(db, "one"), 1L)
  expect_equal(task_list(db, status = "all")$description, "two")  # 'two' untouched
  expect_equal(task_purge(db), 0L)                                # trash already empty
})

test_that("task_modify updates fields and replaces tags", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Old", project = "A", tags = "x")
  id <- task_list(db)$id[1]
  task_modify(db, id, description = "New", project = "B", tags = c("y", "z"), priority = "M")
  out <- task_list(db)
  expect_equal(out$description, "New")
  expect_equal(out$project, "B")
  expect_equal(out$priority, "M")
  expect_false(grepl("x", out$tags))
  expect_true(grepl("y", out$tags) && grepl("z", out$tags))
})

test_that("sorting by due date works in both directions, empties last", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "mid",  due = format(Sys.Date() + 5, "%Y-%m-%d"))
  task_add(db, "soon", due = format(Sys.Date() + 1, "%Y-%m-%d"))
  task_add(db, "late", due = format(Sys.Date() + 9, "%Y-%m-%d"))
  task_add(db, "none")                                  # no due date
  asc  <- task_list(db, sort = "due")
  desc <- task_list(db, sort = "due", desc = TRUE)
  expect_equal(asc$description,  c("soon", "mid", "late", "none"))
  expect_equal(desc$description, c("late", "mid", "soon", "none"))  # empty still last
})

test_that("sorting by creation date can be reversed", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "first"); Sys.sleep(1); task_add(db, "second")
  expect_equal(task_list(db, sort = "entry")$description, c("first", "second"))
  expect_equal(task_list(db, sort = "entry", desc = TRUE)$description, c("second", "first"))
})

test_that("urgency ranks priority and due, blocked sinks", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "low")
  task_add(db, "high prio", priority = "H")
  task_add(db, "due soon", due = format(Sys.Date(), "%Y-%m-%d"))
  out <- task_list(db)  # sorted by urgency desc
  expect_true(which(out$description == "high prio") < which(out$description == "low"))
  expect_true(out$urgency[out$description == "high prio"] > out$urgency[out$description == "low"])
})

test_that(".task_uuid produces unique 36-char ids", {
  ids <- replicate(50, daos:::.task_uuid())
  expect_true(all(nchar(ids) == 36))
  expect_equal(length(unique(ids)), 50)
})

test_that(".task_advance moves dates by period or days", {
  expect_equal(daos:::.task_advance("2026-01-01", "weekly"), "2026-01-08")
  expect_equal(daos:::.task_advance("2026-01-01", "10"), "2026-01-11")
  expect_equal(daos:::.task_advance("2026-01-15", "monthly"), "2026-02-15")
})

test_that("task_projects counts per project and status", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "a", project = "P1")
  task_add(db, "b", project = "P1")
  task_add(db, "c", project = "P2")
  task_done(db, task_list(db, project = "P1")$id[1])
  pr <- task_projects(db)
  expect_equal(pr$pending[pr$project == "P1"], 1)
  expect_equal(pr$completed[pr$project == "P1"], 1)
  expect_equal(pr$total[pr$project == "P1"], 2)
  expect_equal(pr$pct_done[pr$project == "P1"], 50)
  expect_equal(pr$pending[pr$project == "P2"], 1)
  expect_true(all(c("created", "last_activity", "overdue") %in% names(pr)))
  expect_match(pr$created[pr$project == "P1"], "^\\d{4}-\\d{2}-\\d{2}$")
})

test_that("task_projects counts overdue pending tasks", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "late", project = "P", due = format(Sys.Date() - 1, "%Y-%m-%d"))
  task_add(db, "soon", project = "P", due = format(Sys.Date() + 5, "%Y-%m-%d"))
  pr <- task_projects(db)
  expect_equal(pr$overdue[pr$project == "P"], 1)
})

test_that("invalid priority and date are rejected", {
  db <- tmp_db(); on.exit(unlink(db))
  expect_error(task_add(db, "x", priority = "Z"), "priority")
  expect_error(task_add(db, "x", due = "not-a-date"), "date")
})

test_that("a key can stand in for the id everywhere", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Compile accounts", key = "compile-accounts")
  expect_equal(task_list(db)$key, "compile-accounts")
  # get / require / done / annotate / blockers all accept the key
  expect_equal(task_get(db, "compile-accounts")$description, "Compile accounts")
  task_annotate(db, "compile-accounts", "started")
  expect_equal(task_annotations(db, "compile-accounts")$text, "started")
  task_done(db, "compile-accounts", note = "done")
  expect_equal(task_get(db, "compile-accounts")$status, "completed")
  expect_equal(task_require(db, "compile-accounts"), "compile-accounts")
})

test_that("id and uuid keep working alongside a key", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Has a key", key = "the-key")
  row <- task_list(db)
  expect_equal(task_get(db, row$id)$description, "Has a key")     # integer id
  expect_equal(task_get(db, row$uuid)$description, "Has a key")   # uuid
  expect_equal(task_get(db, row$key)$description, "Has a key")    # key
})

test_that("dependencies can be expressed by key", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "Upstream", key = "up")
  task_add(db, "Downstream", depends = "up")
  lst <- task_list(db)
  expect_true(lst$blocked[lst$description == "Downstream"])
  task_done(db, "up")
  expect_false(task_list(db)$blocked[task_list(db)$description == "Downstream"])
})

test_that("keys are validated and must be unique", {
  db <- tmp_db(); on.exit(unlink(db))
  expect_error(task_add(db, "x", key = "Has Spaces"), "slug")
  expect_error(task_add(db, "x", key = "UPPER"), "slug")
  expect_error(task_add(db, "x", key = "123"), "digits")
  task_add(db, "first", key = "dup")
  expect_error(task_add(db, "second", key = "dup"), "already in use")
})

test_that("task_modify sets, renames, and clears a key", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "A")
  id <- task_list(db)$id[1]
  task_modify(db, id, key = "alpha")
  expect_equal(task_get(db, "alpha")$description, "A")
  task_modify(db, "alpha", key = "beta")                 # rename via key
  expect_equal(task_get(db, "beta")$description, "A")
  expect_error(task_get(db, "alpha"), "No task")
  task_modify(db, "beta", key = "")                      # clear
  expect_true(is.na(task_list(db)$key[1]))
})

test_that("renaming to an in-use key is rejected", {
  db <- tmp_db(); on.exit(unlink(db))
  task_add(db, "A", key = "a")
  task_add(db, "B", key = "b")
  expect_error(task_modify(db, "b", key = "a"), "already in use")
})

test_that("a pre-key database is migrated and then accepts keys", {
  skip_if_not_installed("RSQLite")
  db <- tmp_db(); on.exit(unlink(db))
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  # An older schema: tasks without the key column, plus the sibling tables.
  DBI::dbExecute(con, "CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL, project TEXT, assignee TEXT, priority TEXT,
    status TEXT NOT NULL DEFAULT 'pending', due TEXT,
    entry TEXT NOT NULL, modified TEXT NOT NULL, end TEXT, recur TEXT)")
  DBI::dbExecute(con, "CREATE TABLE task_tags (task_uuid TEXT, tag TEXT, UNIQUE(task_uuid, tag))")
  DBI::dbExecute(con, "CREATE TABLE annotations (id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_uuid TEXT, entry TEXT, text TEXT)")
  DBI::dbExecute(con, "CREATE TABLE dependencies (task_uuid TEXT, depends_on_uuid TEXT,
    UNIQUE(task_uuid, depends_on_uuid))")
  DBI::dbDisconnect(con)

  task_add(db, "legacy", key = "leg")            # opening triggers the migration
  expect_true("key" %in% names(task_list(db)))
  expect_equal(task_get(db, "leg")$description, "legacy")
})
