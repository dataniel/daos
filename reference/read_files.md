# Read one or more files with automatic format detection

Detects the file format from the extension and dispatches to the
appropriate reader. Supports a wide range of tabular, statistical, and
structured formats. When multiple paths are supplied, a named list is
returned and a progress bar is shown.

## Usage

``` r
read_files(paths, ...)
```

## Arguments

- paths:

  A single file path or a character vector of file paths. If the vector
  is unnamed, file names (without extension) are used as list names.

- ...:

  Additional arguments forwarded to the underlying reader.

## Value

For a single path: the object returned by the reader. For multiple
paths: a named list of objects.

## Details

**Supported formats:**

**Note on CSV:** `read_files()` uses
[`readr::read_csv2()`](https://readr.tidyverse.org/reference/read_delim.html)
for `.csv` files, which expects **semicolon-separated** values and a
comma as the decimal mark (the Danish/European convention). If your CSV
uses commas as separators, pass the file directly to
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
instead.

|                                        |                                                                                                                                                                                         |
|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Extension                              | Reader                                                                                                                                                                                  |
| `csv`                                  | [`readr::read_csv2()`](https://readr.tidyverse.org/reference/read_delim.html) (semicolon-separated, European format)                                                                    |
| `tsv`                                  | [`readr::read_tsv()`](https://readr.tidyverse.org/reference/read_delim.html)                                                                                                            |
| `parquet`, `feather`                   | [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html) / [`arrow::read_feather()`](https://arrow.apache.org/docs/r/reference/read_feather.html)         |
| `xlsx`, `xls`                          | [`readxl::read_xlsx()`](https://readxl.tidyverse.org/reference/read_excel.html) / [`readxl::read_xls()`](https://readxl.tidyverse.org/reference/read_excel.html)                        |
| `rds`                                  | [`readRDS()`](https://rdrr.io/r/base/readRDS.html)                                                                                                                                      |
| `sas7bdat`, `sav`, `por`, `xpt`, `dta` | `haven::read_*()`                                                                                                                                                                       |
| `json`, `ndjson`, `jsonl`              | [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html) / [`jsonlite::stream_in()`](https://jeroen.r-universe.dev/jsonlite/reference/stream_in.html) |
| `yaml`, `yml`                          | [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)                                                                                                                  |
| `txt`                                  | [`readr::read_lines()`](https://readr.tidyverse.org/reference/read_lines.html)                                                                                                          |

Packages for non-base formats (`arrow`, `haven`, `readxl`, `jsonlite`,
`yaml`) must be installed separately.

## See also

[`require_files()`](https://dataniel.github.io/daos/reference/require_files.md),
[`bind_files()`](https://dataniel.github.io/daos/reference/bind_files.md),
[`unpack_files()`](https://dataniel.github.io/daos/reference/unpack_files.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Single file
df <- read_files("data/results.parquet")

# Multiple files — returns a named list
files <- read_files(c("data/a.csv", "data/b.csv"))

# Pipeline with require_files() and bind_files():
require_files("data/dat{0:9}.parquet") |>
  read_files() |>
  bind_files()
} # }
```
