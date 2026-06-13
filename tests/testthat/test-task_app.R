skip_if_not_installed("shiny")
skip_if_not_installed("RSQLite")

# Drive the real app server with testServer (no browser). This guards the
# add/refresh cycle -- earlier a self-referential reactiveVal made the
# timer observe loop and starved the session.

test_that("adding a task updates the task list", {
  db <- tempfile(fileext = ".sqlite"); on.exit(unlink(db))
  task_db(db)
  shiny::testServer(daos:::.task_app_server(normalizePath(db, winslash = "/", mustWork = FALSE)), {
    session$setInputs(f_status = "pending", f_sort = "urgency",
                      f_project = "", f_assignee = "", f_tag = "",
                      n_desc = "First task", n_project = "", n_assignee = "Anna",
                      n_tags = "", n_priority = "", n_due = "", n_recur = "")
    expect_equal(nrow(tasks()), 0)
    session$setInputs(add = 1)
    expect_equal(nrow(tasks()), 1)
    expect_equal(tasks()$description, "First task")
    expect_equal(tasks()$assignee, "Anna")
  })
})

test_that("completing a selected task removes it from pending", {
  db <- tempfile(fileext = ".sqlite"); on.exit(unlink(db))
  task_db(db)
  task_add(db, "to finish")
  id <- task_list(db)$id[1]
  shiny::testServer(daos:::.task_app_server(normalizePath(db, winslash = "/", mustWork = FALSE)), {
    session$setInputs(f_status = "pending", f_sort = "urgency",
                      f_project = "", f_assignee = "", f_tag = "")
    session$setInputs(pick_task = id)
    session$setInputs(act_done = 1)
    expect_equal(nrow(tasks()), 0)
  })
})
