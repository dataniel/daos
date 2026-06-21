# Project overview for managers

One row per project, built for a quick read of where each production
stands: a health signal, how much is pending, in progress, blocked, done
and overdue, how much has stalled, the next deadline, and the first/last
activity. Designed so a lead can scan it and see what is on track and
where the bottlenecks are.

## Usage

``` r
task_projects(db, stale_days = 14)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- stale_days:

  A pending task untouched for more than this many days (and neither
  started nor blocked) counts as stalled. Default 14.

## Value

A tibble, one row per project, with `project`, `health` (`"green"`,
`"amber"`, `"red"`, or `"done"`), `pending`, `started`, `blocked`,
`completed`, `total`, `pct_done`, `overdue`, `stalled`, `next_due` (a
`Date`), `days_to_due`, `created`, and `last_activity`. Health is `red`
with any overdue task, `amber` with a blocker, a stalled task or a
deadline within a week, `green` otherwise, and `done` when nothing is
pending.

## See also

[`task_bottlenecks()`](https://dataniel.github.io/daos/reference/task_bottlenecks.md),
[`task_people()`](https://dataniel.github.io/daos/reference/task_people.md),
[`task_activity()`](https://dataniel.github.io/daos/reference/task_activity.md)
