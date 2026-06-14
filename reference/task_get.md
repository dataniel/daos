# Get one or more tasks by id

Returns the same row
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
would show – with the `blocked` flag, `urgency`, and annotation count –
for the given id(s). A convenience over filtering
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
by hand when you only want a specific task.

## Usage

``` r
task_get(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  One or more task ids (the small integers).

## Value

A tibble with one row per id, in the order given.

## See also

[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md),
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md)
