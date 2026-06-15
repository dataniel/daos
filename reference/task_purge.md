# Permanently delete tasks

Removes tasks from the database for good – together with their tags,
annotations, and dependency links. Where
[`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md)
only marks a task `deleted` so it can still be reopened, this is the
hard delete that empties the trash, and it cannot be undone.

## Usage

``` r
task_purge(db, id = NULL)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Tasks to purge: integer id, uuid, or key. If `NULL` (default), every
  soft-deleted task is removed – i.e. empty the trash.

## Value

The number of tasks purged, invisibly.

## See also

[`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md),
[`task_reopen()`](https://dataniel.github.io/daos/reference/task_reopen.md)
