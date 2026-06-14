# Why a task is blocked

Returns the prerequisites a task depends on that are not yet completed –
the unfinished tasks that make
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
report it as `blocked`. An empty result means nothing is holding it up.

## Usage

``` r
task_blockers(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  A single task id (integer or uuid).

## Value

A tibble with `id`, `uuid`, `description`, and `status` of each
unfinished prerequisite.

## See also

[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md),
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md)
