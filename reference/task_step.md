# Run a production step under a task

Wraps one step of a production script so it both runs and records
itself: the task is marked started, `expr` is evaluated, and then – on
success – annotated and completed; on failure it is annotated with the
error, un-started, and the error re-raised. This turns the hand-rolled
`run_step()` pattern into one call, so a pipeline leaves a trace of what
happened without status code creeping into the analysis.

## Usage

``` r
task_step(db, id, expr, note = NULL)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task identifier: the integer id, the uuid, or the key.

- expr:

  The step to run. Evaluated once; its value is returned.

- note:

  Optional success note. Defaults to a timestamped `"ok: ..."`.

## Value

The value of `expr`, invisibly. On error, the error is re-raised after
the task is annotated and un-started.

## Details

Keep it *beside* the work: `expr` should be the step that produces the
result, with the task call wrapping it, not task code woven into a data
pipeline.

## See also

[`task_start()`](https://dataniel.github.io/daos/reference/task_start.md),
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md),
[`task_cycle()`](https://dataniel.github.io/daos/reference/task_cycle.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_step(db, "compile-accounts", {
  stats <- compile(sources)
  stats
})
} # }
```
