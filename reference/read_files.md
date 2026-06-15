# Read one or more files

Expands paths using
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html) (so
`{0:9}` generates ten paths), checks that every file exists, reads them
with automatic format detection or a custom reader, and optionally
row-binds or unpacks the result.

## Usage

``` r
read_files(
  paths,
  names = NULL,
  reader = "auto",
  out = NULL,
  .envir = parent.frame(),
  .id = NULL,
  .overwrite = FALSE,
  .lowercase = TRUE,
  ...
)
```

## Arguments

- paths:

  A character vector of file paths. Glue syntax
  ([`{}`](https://rdrr.io/r/base/Paren.html)) is supported for compact
  range expansion.

- names:

  Optional names for the result. Defaults to file names without
  extension. If numeric, the `.id` column (when `out = "bind"`) will
  also be numeric.

- reader:

  `"auto"` (default) to detect the format from the file extension, or a
  function `\(path, ...) ...` to use a custom reader.

- out:

  Controls what is returned after reading:

  - `NULL` (default): the object directly for a single file; a named
    list for multiple files.

  - `"bind"`: row-bind all data frames into a single tibble. If column
    types differ, a warning is issued and types are reconciled with
    [`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html).
    A source column is added when `.id` is set.

  - `"unpack"`: assign each element as a named variable in `.envir`.

- .envir:

  Environment used for glue interpolation and (when `out = "unpack"`)
  the target for assignment. Default is the calling frame.

- .id:

  Name of a source column added when `out = "bind"`. If `NULL`
  (default), no source column is added.

- .overwrite:

  If `FALSE` (default), aborts when any name already exists in `.envir`
  and `out = "unpack"`. Set to `TRUE` to allow overwrites.

- .lowercase:

  If `TRUE` (default), column names are converted to lowercase after
  reading. Set to `FALSE` to preserve original casing.

- ...:

  Additional arguments forwarded to the reader function.

## Value

Depends on `out`:

- `NULL`: the object (single file) or a named list (multiple files).

- `"bind"`: a single tibble.

- `"unpack"`: the named list, invisibly.

## Details

**Supported formats (when `reader = "auto"`):**

**Note on CSV:** uses
[`readr::read_csv2()`](https://readr.tidyverse.org/reference/read_delim.html)
which expects semicolon-separated values and a comma as the decimal mark
(Danish/European convention). For comma-separated files, pass a custom
reader: `reader = readr::read_csv`.

**Note on Excel:** only the first sheet is read. If a workbook has
several and you did not name one, a warning lists the others. Read a
specific sheet by forwarding the argument:
`read_files("x.xlsx", sheet = "Sheet2")`.

|  |  |
|----|----|
| Extension | Reader |
| `csv` | [`readr::read_csv2()`](https://readr.tidyverse.org/reference/read_delim.html) (semicolon-separated, European format) |
| `tsv` | [`readr::read_tsv()`](https://readr.tidyverse.org/reference/read_delim.html) |
| `parquet`, `feather` | [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html) / [`arrow::read_feather()`](https://arrow.apache.org/docs/r/reference/read_feather.html) |
| `xlsx`, `xls` | [`readxl::read_xlsx()`](https://readxl.tidyverse.org/reference/read_excel.html) / [`readxl::read_xls()`](https://readxl.tidyverse.org/reference/read_excel.html) |
| `rds` | [`readRDS()`](https://rdrr.io/r/base/readRDS.html) |
| `sas7bdat`, `sav`, `por`, `xpt`, `dta` | `haven::read_*()` |
| `json`, `ndjson`, `jsonl` | [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html) / [`jsonlite::stream_in()`](https://jeroen.r-universe.dev/jsonlite/reference/stream_in.html) |
| `yaml`, `yml` | [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html) |
| `txt` | [`readr::read_lines()`](https://readr.tidyverse.org/reference/read_lines.html) |

Packages for non-base formats (`arrow`, `haven`, `readxl`, `jsonlite`,
`yaml`) must be installed separately.

## See also

[`summon()`](https://dataniel.github.io/daos/reference/summon.md),
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Single file (returns object directly):
df <- read_files("data/results.parquet")

# Multiple files with glue expansion:
lst <- read_files("data/dat{0:9}.parquet", names = 0:9)

# Custom reader:
lst <- read_files(
  "data/dat{0:9}.parquet",
  reader = \(x) arrow::read_parquet(x, col_select = 1:5)
)

# Read and bind into one tibble:
df <- read_files("data/dat{0:9}.parquet", names = 0:9, out = "bind")

# Read and unpack into individual variables (dat0, dat1, ...):
read_files("data/dat{0:9}.parquet", names = paste0("dat", 0:9), out = "unpack")
summon("^dat\\d+$")
} # }
```
