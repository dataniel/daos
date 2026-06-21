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

task_add(db, "Compile the accounts statistics", key = "compile-accounts",
         project = "RS-2026", assignee = "pipeline",
         priority = "H", due = "2026-07-15")

# ... the step runs ...
rows <- nrow(result)
task_annotate(db, "compile-accounts", paste("Compiled", rows, "rows at", nowf("%H:%M")))
task_done(db, "compile-accounts")
```

Now anyone watching the project in the app sees the step move to done,
with a timestamped note about what it produced. The production process
became observable without anyone writing a status report.

## Refer to a task by a key, not a number

Notice that the step above is closed with `"compile-accounts"`, not a
number. Every task has an integer `id` and a `uuid`, and both still
work, but neither is a good thing to hard-code in a script. An id like
`7` says nothing about which task it is, and if the database has been
reorganised since you wrote the line, `7` may no longer be the task you
meant – the call would quietly act on the wrong one. A `key` is a
stable, readable name you choose yourself when you add the task:

``` r

task_add(db, "Validate sources", key = "validate-sources", project = "RS-2026")
```

and then use anywhere an id is accepted –
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md),
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md),
[`task_annotate()`](https://dataniel.github.io/daos/reference/task_annotate.md),
`depends =`, and the rest:

``` r

task_done(db, "validate-sources")
```

Beyond reading better, this is *safer*: a key fails loudly. If
`validate-sources` has been removed or renamed, the call stops with an
error instead of silently resolving to whatever task now sits at a given
number. Keys are slugs (lowercase letters and digits joined by `-` or
`_`) and must be unique; set or change one later with
`task_modify(db, id, key = "...")`, or clear it with `key = ""`.

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

## Keep the tracking beside the work, not inside it

One habit is worth keeping: let the task calls run *alongside* your
analysis, never inside the pipeline that produces the numbers. It is
tempting to weave a note into a `dplyr` chain, but the moment task code
sits in the data path, a reader has to wonder whether it touches the
result. Keep it out, and there is nothing to wonder about – the
statistics stay a plain pipeline, and the tracking is ordinary
statements next to it that read from what the analysis already produced:

``` r

# the statistics -- untouched, no task code in here
stats <- df |>
  dplyr::group_by(group) |>
  dplyr::summarise(n = dplyr::n(), mean_x = mean(x), .groups = "drop")

# the tracking -- beside it, reading from the result
task_done(db, 2, note = f("computed: {nrow(stats)} groups, {sum(stats$n)} obs"))
```

The note reads `nrow(stats)` and `sum(stats$n)` from the result the
analysis already produced, so it records what happened without ever
entering the analysis itself.
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)
takes an optional `note`, so closing a step and recording what it
produced is a single line next to the work. That is the whole idea: the
statistics are exactly the pipeline you would have written anyway, and
the task tracking sits next to it.

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

task_add(db, "Compile accounts", project = "RS-2026",
         depends = "validate-sources")          # waits for the keyed task above

ready <- task_list(db, status = "pending")
ready[!ready$blocked, ]   # what can be started now
```

[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
adds the `blocked` flag and a simplified urgency score (priority,
due-date nearness, age, tags, a blocked penalty) and sorts by it, so the
top of the list is the thing to do next.

In a single script, the same idea becomes a gate: run
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md)
before a step that depends on an earlier one, and it stops with a clear
error unless the upstream task is done. Like everything else here it
only reads the task database – it never touches your data – so it sits
beside the analysis:

``` r

task_require(db, "validate-sources")   # abort unless that task is done

stats <- compile(sources)              # only runs once the dependency is satisfied
task_done(db, "compile-accounts", note = f("compiled: {nrow(stats)} rows"))
```

`task_get(db, id)` is the matching read accessor: the single row
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
would show for one task, when you want to branch on its `status` or
`blocked` flag instead of aborting. And when a task *is* blocked,
`task_blockers(db, id)` says why – it returns the unfinished
prerequisites holding it up, which is also what the app shows in a
blocked task’s detail panel.

## One call for a whole cycle, and what is in progress

A production with a fixed sequence of steps can be set up in one call.
[`task_cycle()`](https://dataniel.github.io/daos/reference/task_cycle.md)
adds the steps for a project and wires each to depend on the previous,
with the deadline – and an optional recurrence, so the release date
rolls forward each cycle – on the last:

``` r

task_cycle(db, "RS-2026",
  steps = c("Hent kilder", "Valider", "Kompiler", "Publicer"),
  keys  = c("hent", "valider", "kompiler", "publicer"),
  assignee = "pipeline", due = "2026-07-15", recur = "monthly")
```

Only the first step is unblocked; each later one becomes ready as its
predecessor is done.
[`task_step()`](https://dataniel.github.io/daos/reference/task_step.md)
then runs one step and records it in a single call – it marks the task
started, evaluates the expression, and on success annotates and
completes it (on failure it notes the error, un-starts the task, and
re-raises), so the whole `run_step()` wrapper above collapses to:

``` r

task_step(db, "kompiler", {
  stats <- compile(sources)
  stats
})
```

[`task_start()`](https://dataniel.github.io/daos/reference/task_start.md)
and
[`task_stop()`](https://dataniel.github.io/daos/reference/task_start.md)
toggle the in-progress flag by hand, so the overview shows what is being
*worked on right now*, not just what is pending.

## Reading the state back

Everything written from scripts is queryable from scripts.
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
filters by status, project, assignee, and tag, and flags what is
`blocked` and `started`;
[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md)
gives a manager overview per project (a health signal, in-progress,
blocked, overdue and stalled counts, progress, and the next deadline);
[`task_people()`](https://dataniel.github.io/daos/reference/task_people.md)
does the same per assignee (load, overdue, recently done).
[`task_bottlenecks()`](https://dataniel.github.io/daos/reference/task_bottlenecks.md)
ranks the tasks blocking the most others, and
[`task_activity()`](https://dataniel.github.io/daos/reference/task_activity.md)
is a newest-first feed of what has moved. A production dashboard, an
email summary, or a check that nothing is overdue is then a few lines of
R against the same shared file the app reads:

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

The app is keyboard-driven – `j`/`k` to move, `f` done, `s` start/stop
(in progress), `e` edit, `n` note, `g` reopen, `x` delete, `r` reset
filters, `o`/`p` to switch between the tasks and projects pages, `q` to
quit – and re-reads the database on a timer, so changes a script makes
appear without a manual refresh. The Projekter page is a manager
dashboard: per-project health (on track / at risk / behind), what is in
progress, blocked, overdue and stalled, the bottleneck tasks blocking
the most others, and a recent-activity feed.

Deleting is a soft delete:
[`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md)
(and `x` in the app) only marks a task `deleted` so it can be reopened,
which is why it disappears from the default
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
and from the app’s “Alle” view but still lives in the database. The
app’s “Slettede” view is the trash – reopen from there, or empty it for
good with
[`task_purge()`](https://dataniel.github.io/daos/reference/task_purge.md),
the irreversible hard delete.
