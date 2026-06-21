# People overview

One row per assignee with their current load: pending, in progress,
blocked and overdue tasks, how many they have completed in the last 30
days, and across how many projects – enough to spot who is overloaded or
where a person has become a bottleneck.

## Usage

``` r
task_people(db)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

## Value

A tibble with `assignee`, `pending`, `started`, `blocked`, `overdue`,
`done30`, and `projects`.

## See also

[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md),
[`task_bottlenecks()`](https://dataniel.github.io/daos/reference/task_bottlenecks.md)
