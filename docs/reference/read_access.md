# Read data from a Microsoft Access database

Connects to a Microsoft Access database (`.mdb` or `.accdb`) via ODBC,
executes a SQL query, and returns the result as a tibble.

## Usage

``` r
read_access(path, sql, verbosity = c("compact", "full", "quiet"))
```

## Arguments

- path:

  Path to the Access database file. Can be a string or an
  [`fs::path`](https://rdrr.io/pkg/fs/man/path.html) object. Both `.mdb`
  and `.accdb` files are supported.

- sql:

  A SQL query string to execute against the database.

- verbosity:

  Level of status output. One of:

  - `"full"` – header, per-step spinners, and summary. Best for
    interactive single-file use.

  - `"compact"` – a single-line summary per file. Best when iterating
    over many databases. This is the default.

  - `"quiet"` – no output.

## Value

A [`tibble`](https://rdrr.io/pkg/tibble/man/tibble.html) containing the
query result.

## Examples

``` r
if (FALSE) { # \dontrun{
# single file – use full output
data <- read_access("sales.mdb", "SELECT * FROM Customers",
                    verbosity = "full")

# many files – compact output is the default
files <- fs::dir_ls("data", glob = "*.mdb")
all_data <- files |>
  purrr::map(\(f) read_access(f, "SELECT * FROM Sales"))
} # }
```
