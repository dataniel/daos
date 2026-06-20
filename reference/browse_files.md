# Browse the filesystem and copy paths to R

Launches a Shiny app that walks the local filesystem in a three-column,
yazi-style browser: parent directory, current directory, and a live
preview of the item under the cursor. Navigate with `h`/`j`/`k`/`l` or
the arrow keys. The point is to grab paths without typing them: mark one
or more files or folders and copy them, or return them to R.

## Usage

``` r
browse_files(
  path = getwd(),
  root = NULL,
  map = c("lapply", "purrr"),
  preview = TRUE,
  base_dir = FALSE,
  names = FALSE
)
```

## Arguments

- path:

  Directory to start in. Default: the working directory
  ([`getwd()`](https://rdrr.io/r/base/getwd.html)).

- root:

  Optional directory that caps how far up you can navigate: the browser
  never climbs above it (no parent column, no drive chooser at that
  level). Default `NULL` allows climbing all the way to the filesystem
  root. A `path` outside `root` is pulled back to `root`.

- map:

  Initial iterator for a reader-mode snippet when several files of the
  same type are marked: `"lapply"` (default, base R) or `"purrr"` for
  [`purrr::map()`](https://purrr.tidyverse.org/reference/map.html).
  Toggle it live in the app with `m`. Only affects the generated text,
  not the browser itself.

- preview:

  Whether the content preview starts on (`TRUE`, default) – the text
  peek for scripts/text and the cell peek for Excel sheets. The preview
  column (file metadata, folder contents) is always shown. Toggle the
  content preview live in the app with `p`.

- base_dir:

  Whether to start with a shared `base_dir` factored out of multi-file
  snippets (`FALSE`, default). Toggle it live in the app with `b`.

- names:

  Whether multi-file output starts keyed by file name (`FALSE`,
  default), so a mapped read returns a named list. Toggle live with `n`.

## Value

The target paths, invisibly – a single string when one path is marked or
the cursor path is used, a character vector when several are marked.
`character(0)` if nothing is resolved.

## Details

- `Space` marks/unmarks the item under the cursor (files or folders).
  The *target* is the marked paths, or the cursor path when none are
  marked.

- `Enter` (or the button) inserts the target into the active RStudio
  editor or console as an R expression and closes the app – a quoted
  string for one path, a multi-line `c(...)` (one path per line) for
  several, with forward slashes. Outside RStudio it falls back to the
  clipboard.

- `r` toggles *reader mode*: when on, `Enter` and `y` insert a call that
  reads the target with the native reader for its type (e.g.
  [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html)
  for `.parquet`,
  [`readxl::read_xlsx()`](https://readxl.tidyverse.org/reference/read_excel.html)
  for `.xlsx`,
  [`readr::read_csv2()`](https://readr.tidyverse.org/reference/read_delim.html)
  for `.csv`) instead of the bare path – so the pasted line is
  self-contained and needs no `daos`. A single file is read inline
  (`arrow::read_parquet("data/x.parquet")`); several files of the same
  type are bound to a `my_paths` object and the reader is mapped over
  them (`lapply(my_paths, arrow::read_parquet)`, or `purrr::map(...)`
  when `map = "purrr"`); a mix of types gets one named read per file.
  Only files of a known type are wrapped; folders and unknown types are
  left out (with a warning). Readable files are flagged with a green
  icon in the browser. Toggle it off to go back to plain paths.

- On an Excel file (`.xlsx`/`.xls`), `l`/Enter steps *into* the workbook
  and lists its sheets; mark sheets with `Space` and the inserted code
  reads exactly those – one
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html)
  call per sheet (a single sheet reads inline). The preview shows the
  first rows of the sheet under the cursor. `h` leaves the workbook.
  Needs `readxl`.

- `y` copies that same expression to the clipboard without closing.

- `o` opens the item under the cursor in the system file explorer via
  [`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)
  (a folder opens, a file is revealed).

- `a` opens the file itself in its default application (the workbook
  when inside one).

- `l`/`->` enters a folder; `h`/`<-` goes up. Without `root` you can
  climb all the way to the drive chooser; with `root` set, climbing
  stops there – that directory becomes the top, with no parent column
  above it. The cursor remembers its place in each folder, so going back
  up lands on the folder you came from. `g` jumps back to the directory
  the browser opened in.

- The filter box above the browser narrows the current folder to
  matching files: a glob when the pattern has `*`/`?` (e.g.
  `*_2026*.tsv`), otherwise a case-insensitive substring. Folders always
  stay visible so you can keep navigating, and the filter clears when
  you move to another folder.

- `m` toggles how a multi-file reader snippet iterates –
  [`lapply()`](https://rdrr.io/r/base/lapply.html) or
  [`purrr::map()`](https://purrr.tidyverse.org/reference/map.html) (see
  `map`). `p` toggles the content preview: when off, the preview column
  still shows file metadata (size, dates, sheet names) but no longer
  reads into files for the text peek or the Excel cell peek.

- `b` toggles a shared `base_dir`: the files' common directory is pulled
  into a `base_dir <- "..."` line and each path becomes
  `paste0(base_dir, "/...")`, so the folder lives in one place. For one
  file that is its own directory; it only has no effect when the files
  share no directory (different drives).

- `n` toggles names: with several files marked, the path vector is keyed
  by file name (`c(iris2 = "...", iris3 = "...")`), so the mapped read
  returns a named list. No effect on a single file.

- Reader (`r`), preview (`p`), base_dir (`b`) and names (`n`) are also
  buttons in the action bar; their icon reflects whether each is on.

- `Q` closes the app without inserting.

## See also

[`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)

## Examples

``` r
if (FALSE) { # \dontrun{
p <- browse_files()          # navigate, mark, press Q
files <- browse_files("data") # start in data/, return marked files
browse_files("data", root = "data") # cannot climb above data/
} # }
```
