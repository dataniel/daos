# Bottlenecks: the tasks blocking the most others

The unfinished prerequisites that hold up the most downstream work – the
real bottlenecks. Each row is a pending task that one or more other
pending tasks depend on, ranked by how many it blocks, so a lead can see
which single task to unblock first.

## Usage

``` r
task_bottlenecks(db)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

## Value

A tibble with `id`, `key`, `description`, `project`, `assignee`, and
`blocking` (the number of pending tasks waiting on it), most blocking
first. Empty when nothing is blocked.

## See also

[`task_blockers()`](https://dataniel.github.io/daos/reference/task_blockers.md),
[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md)
