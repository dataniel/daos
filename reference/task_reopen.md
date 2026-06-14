# Reopen a task

Sets a completed or deleted task back to pending and clears its end time
– the undo for
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)
and
[`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md).

## Usage

``` r
task_reopen(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task identifier: the integer id, the uuid, or the key.

## Value

`TRUE`, invisibly.
