# Start or stop work on a task

`task_start()` marks a pending task as in progress by stamping it with a
start time; `task_stop()` clears that stamp. A started task stays
`pending` – "in progress" is a flag, not a separate status – and
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
reports it through the `started` column. This is what lets the overview
show *what is being worked on right now*, not just what is pending, so a
production step can announce itself when it begins:
`task_start(db, "compile-accounts")` at the top of the step, beside the
work rather than inside it.

## Usage

``` r
task_start(db, id)

task_stop(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task identifier: the integer id, the uuid, or the key.

## Value

`TRUE`, invisibly.

## See also

[`task_step()`](https://dataniel.github.io/daos/reference/task_step.md),
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md),
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_start(db, "compile-accounts")   # now shown as in progress
task_stop(db, "compile-accounts")    # back to plain pending
} # }
```
