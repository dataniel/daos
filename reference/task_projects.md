# Project overview

One row per project with pending/completed/total counts, completion
percentage, the number of overdue pending tasks, the project's start
(earliest task creation) and the most recent activity.

## Usage

``` r
task_projects(db)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

## Value

A tibble with `project`, `pending`, `completed`, `total`, `pct_done`,
`overdue`, `created`, `last_activity`.
