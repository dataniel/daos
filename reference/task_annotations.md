# Annotations of a task

Annotations of a task

## Usage

``` r
task_annotations(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task id (the small integer) or uuid.

## Value

A tibble with `entry` and `text`.
