# Formatted timestamp for now

A shorthand for `format(Sys.time(), fmt)`, with names for the formats
that come up again and again. Useful for constructing file names and log
paths with a timestamp baked in.

## Usage

``` r
nowf(fmt = "date")
```

## Arguments

- fmt:

  A named format, or a format string as accepted by
  [`strftime()`](https://rdrr.io/r/base/strptime.html). Default
  `"date"`.

  |              |                     |                       |
  |--------------|---------------------|-----------------------|
  | Name         | Format              | Example               |
  | `"date"`     | `%Y%m%d`            | `20261102`            |
  | `"datetime"` | `%Y%m%d_%H%M%S`     | `20261102_143022`     |
  | `"iso"`      | `%Y-%m-%d`          | `2026-11-02`          |
  | `"month"`    | `%Y%m`              | `202611`              |
  | `"year"`     | `%Y`                | `2026`                |
  | `"time"`     | `%H%M%S`            | `143022`              |
  | `"stamp"`    | `%Y-%m-%d %H:%M:%S` | `2026-11-02 14:30:22` |

## Value

A single character string with the formatted timestamp.

## Details

The names are words rather than numbers, so `nowf("datetime")` says what
it gives to whoever reads the code next. The file-name formats sort
chronologically and contain no characters Windows forbids; `"stamp"` is
for logs and has colons, so not for file names.

A string without `%` that is not one of the names is an error, so a typo
such as `"datetiem"` does not silently become a file name.

## See also

[`f()`](https://dataniel.github.io/daos/reference/f.md) for string
interpolation

## Examples

``` r
nowf()                 # e.g. "20261102"
#> [1] "20261112"
nowf("datetime")       # e.g. "20261102_143022"
#> [1] "20261112_085847"
nowf("iso")            # e.g. "2026-11-02"
#> [1] "2026-11-12"
nowf("%Y%B")           # any strftime format, e.g. "2026November"
#> [1] "2026November"

# Typical use in file paths:
if (FALSE) { # \dontrun{
f("log/{nowf()}/0-check_data.log")
f("data/export_{nowf('datetime')}.parquet")
} # }
```
