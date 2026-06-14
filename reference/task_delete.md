# Delete a task

Marks the task deleted (it is kept in the database, not removed).

## Usage

``` r
task_delete(db, id)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task identifier: the integer id, the uuid, or the key.

## Value

`TRUE`, invisibly.
