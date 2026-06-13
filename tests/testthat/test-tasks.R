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
