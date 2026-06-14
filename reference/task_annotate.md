# Annotate a task

Adds a timestamped note to a task.

## Usage

``` r
task_annotate(db, id, text)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task id (the small integer) or uuid.

- text:

  The annotation text.

## Value

`TRUE`, invisibly.
