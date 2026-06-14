# Create or open a shared task database

Initialises a SQLite task database (creating the file and tables if they
do not exist) and switches it to WAL mode, so several R processes can
read and write the same file concurrently. Safe to call repeatedly.

## Usage

``` r
task_db(path)
```

## Arguments

- path:

  Path to the `.sqlite` file.

## Value

`path`, invisibly.

## Details

SQLite is free (public domain) and bundled by the `RSQLite` package, so
there is no server to run and nothing to license – a shared `.sqlite`
file on a network drive is enough for a team to work from.

## See also

[`task_add()`](https://dataniel.github.io/daos/reference/task_add.md),
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md),
[`task_app()`](https://dataniel.github.io/daos/reference/task_app.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_db("tasks.sqlite")
} # }
```
