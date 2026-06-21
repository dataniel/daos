# Recent activity across the database

A merged, newest-first feed of what has happened: tasks added,
completed, and annotated. Gives a manager a glance at what is moving
without opening individual tasks.

## Usage

``` r
task_activity(db, n = 20)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- n:

  Maximum number of events to return. Default 20.

## Value

A tibble with `ts` (timestamp), `kind` (`"added"`, `"done"`, or
`"note"`), `id`, `description`, `project`, and `text` (the note, else
`NA`), most recent first.

## See also

[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md),
[`task_annotations()`](https://dataniel.github.io/daos/reference/task_annotations.md)
