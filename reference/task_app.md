# Task manager app

Launches a Shiny app for a shared task database: add, complete, edit,
delete, and annotate tasks, filter by person, project, tag, and status,
and see project and people overviews. Because it works against a shared
SQLite file (see
[`task_db()`](https://dataniel.github.io/daos/reference/task_db.md)),
several people can point at the same file and get a live view; the app
re-reads the database on a timer and after every change.

## Usage

``` r
task_app(db = "tasks.sqlite")
```

## Arguments

- db:

  Path to the task database. **Created if it does not exist**, so
  pointing at a fresh path just starts a new shared database. Can also
  be switched inside the app.

## Value

Runs the app; returns nothing.

## See also

[`task_add()`](https://dataniel.github.io/daos/reference/task_add.md),
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_app("tasks.sqlite")
} # }
```
