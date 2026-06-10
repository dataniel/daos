# Read data from a Microsoft Access database

Connects to a Microsoft Access database (`.mdb` or `.accdb`) via ODBC,
executes a SQL query, and returns the result as a tibble.

## Usage

``` r
read_access(path, sql, verbosity = c("compact", "full", "quiet"))
```

## Arguments

- path:

  Path to the Access database file. Both `.mdb` and `.accdb` files are
  supported.

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

A [`tibble`](https://tibble.tidyverse.org/reference/tibble.html)
containing the query result.

## Examples

``` r
if (FALSE) { # \dontrun{
# single file – use full output
data <- read_access("sales.mdb", "SELECT * FROM Customers",
                    verbosity = "full")

# many files – compact output is the default
files <- list.files("data", pattern = "\\.mdb$", full.names = TRUE)
all_data <- lapply(files, \(f) read_access(f, "SELECT * FROM Sales"))
} # }
```
