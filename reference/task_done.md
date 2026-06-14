# Complete a task

Marks the task completed. If it has a recurrence and a due date, the
next instance is created automatically with the due date advanced (tags
are carried over). This is a simplified recurrence model – one instance
is spawned per completion.

## Usage

``` r
task_done(db, id, note = NULL)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task id (the small integer) or uuid.

- note:

  Optional note to attach as the task is completed, so a step can be
  closed with a one-line annotation instead of a separate
  [`task_annotate()`](https://dataniel.github.io/daos/reference/task_annotate.md)
  call.

## Value

`TRUE`, invisibly.

## See also

[`task_add()`](https://dataniel.github.io/daos/reference/task_add.md),
[`task_delete()`](https://dataniel.github.io/daos/reference/task_delete.md)
