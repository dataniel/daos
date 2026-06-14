# Task management as part of production

The `task_*` family is a small taskwarrior-style task manager backed by
a shared SQLite file. There is the obvious way to use it – open
[`task_app()`](https://dataniel.github.io/daos/reference/task_app.md)
and click around – and a less obvious one that is the real reason it
exists: because every operation is a plain R function call against a
file, task management can live *inside* your production scripts. A
pipeline can open a task, advance it, annotate it with what it produced,
and close it, all as it runs. The same database the team browses in the
app then doubles as a live record of how production is going.

This article is about that second way of working. For the function-by-
function reference, see the help pages; for the app, just run it.

## The database is just a shared file

SQLite is free (public domain, bundled by `RSQLite`), runs in WAL mode,
and needs no server. A `.sqlite` file on a network drive is enough for a
team to work from, several people at once. Every `task_*` function opens
a short-lived connection, does its work in one transaction, and closes,
so concurrent callers – a colleague in the app and a scheduled script –
do not step on each other.

``` r
task_db("//server/share/production/tasks.sqlite")  # create or open
```

Point at a path that does not exist yet and a fresh database is created.
That is the whole setup.

## Two audiences, one database

A production process usually has two kinds of people around it: the ones
running it, and the ones who just want to know whether it is on track.
The app serves the second group without asking anything of them – they
open it, filter by project, and see what is pending, blocked, done, and
overdue, updating on a timer as the scripts run. They never touch R.

The first group writes to the same database from their scripts. That is
where the interesting part is.

## Driving tasks from a production script

Think of the accounts statistics: a production with a handful of steps –
pull the sources, validate, compile, publish. Instead of tracking that
in your head or a spreadsheet, let the script record it. Add the step as
a task at the start, annotate it with what actually happened, and mark
it done when the step succeeds:

``` r
db <- "//server/share/production/tasks.sqlite"

task_add(db, "Compile the accounts statistics",
         project = "RS-2026", assignee = "pipeline",
         priority = "H", due = "2026-07-15")

# ... the step runs ...
rows <- nrow(result)
task_annotate(db, id = 7, paste("Compiled", rows, "rows at", nowf("%H:%M")))
task_done(db, id = 7)
```

Now anyone watching the project in the app sees the step move to done,
with a timestamped note about what it produced. The production process
became observable without anyone writing a status report.

A natural pattern is to wrap the step so success and failure both leave
a trace. On success the task is annotated and closed; on failure it
stays pending and the error is recorded, so the next person sees exactly
where production stopped and why:

``` r
run_step <- function(db, id, expr) {
  out <- tryCatch(force(expr), error = function(e) e)
  if (inherits(out, "error")) {
    task_annotate(db, id, paste("FAILED:", conditionMessage(out)))
    stop(out)
  }
  task_annotate(db, id, paste("ok:", nowf("%Y-%m-%d %H:%M")))
  task_done(db, id)
  out
}

run_step(db, 7, compile_accounts(sources))
```

Because
[`task_annotate()`](https://dataniel.github.io/daos/reference/task_annotate.md)
only appends, the annotations accumulate into a log: every run of a
recurring step adds its own line, and the history is there in the app’s
detail view.

## Recurrence fits scheduled work

A production that repeats does not need a fresh task each cycle. Give
the task a `recur` and
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)
spawns the next occurrence with the due date rolled forward, so a
scheduled job can close this month’s task and next month’s appears
automatically:

``` r
task_add(db, "Monthly source refresh",
         project = "RS", recur = "monthly", due = "2026-07-01")
```

The recurrence handling is deliberately simple (documented on
[`?task_done`](https://dataniel.github.io/daos/reference/task_done.md));
it is meant for “this comes round again”, not for a full calendar
engine.

## Dependencies express the order of production

Steps that must happen in sequence can say so. A task that depends on
another is reported as `blocked` until its dependency is done, so a
script – or a person in the app – can see what is *ready* to run rather
than just what is pending:

``` r
task_add(db, "Validate sources",  project = "RS-2026")        # id 10
task_add(db, "Compile accounts",  project = "RS-2026",
         depends = 10)                                          # waits for 10

ready <- task_list(db, status = "pending")
ready[!ready$blocked, ]   # what can be started now
```

[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
adds the `blocked` flag and a simplified urgency score (priority,
due-date nearness, age, tags, a blocked penalty) and sorts by it, so the
top of the list is the thing to do next.

## Reading the state back

Everything written from scripts is queryable from scripts.
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
filters by status, project, assignee, and tag;
[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md)
gives a per-project overview (pending, completed, overdue, progress,
creation and last-activity dates);
[`task_people()`](https://dataniel.github.io/daos/reference/task_people.md)
does the same per assignee. A production dashboard, an email summary, or
a check that nothing is overdue is then a few lines of R against the
same shared file the app reads:

``` r
overview <- task_projects(db)
overdue  <- task_list(db, status = "pending")
overdue  <- overdue[!is.na(overdue$due) & overdue$due < Sys.Date(), ]
```

## Or just use the app

None of this is required. If you only want a shared to-do board with
projects, people, due dates, and overviews, run
`task_app("tasks.sqlite")` and never write a line of `task_*` code. The
point of the article is that the same database supports both: the team
clicks, the pipeline writes, and the two views agree because there is
only ever one file.

``` r
task_app("//server/share/production/tasks.sqlite")
```

The app is keyboard-driven – `j`/`k` to move, `f` done, `e` edit, `n`
note, `g` reopen, `x` delete, `r` reset filters, `o`/`p` to switch
between the tasks and projects pages, `q` to quit – and re-reads the
database on a timer, so changes a script makes appear without a manual
refresh.
