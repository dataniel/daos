# Require tasks to have a given status

Aborts unless every task in `id` has one of the statuses in `status`
(`"completed"` by default). This is a lightweight gate for coordinating
a production script: call it before a step that depends on earlier ones
being done. It only reads the task database and never touches your data,
so it belongs beside the analysis rather than inside it.

## Usage

``` r
task_require(db, id, status = "completed")
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  One or more task ids (the small integers).

- status:

  Allowed status values; each task must be in one of them.

## Value

`id`, invisibly.

## See also

[`task_get()`](https://dataniel.github.io/daos/reference/task_get.md),
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_require(db, 1)            # stop unless task 1 is done
task_require(db, c(1, 2))      # ... or several upstream steps
} # }
```
