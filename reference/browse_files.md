# Browse the filesystem and copy paths to R

Launches a Shiny app that walks the local filesystem in a three-column,
yazi-style browser: parent directory, current directory, and a live
preview of the item under the cursor. Navigate with `h`/`j`/`k`/`l` or
the arrow keys. The point is to grab paths without typing them: mark one
or more files or folders and copy them, or return them to R.

## Usage

``` r
browse_files(path = getwd())
```

## Arguments

- path:

  Directory to start in. Default: the working directory
  ([`getwd()`](https://rdrr.io/r/base/getwd.html)).

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

- `y` copies that same expression to the clipboard without closing.

- `o` opens the item under the cursor in the system file explorer via
  [`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)
  (a folder opens, a file is revealed).

- `l`/`->` enters a folder; `h`/`<-` goes up, all the way to the drive
  chooser at the root. The cursor remembers its place in each folder, so
  going back up lands on the folder you came from.

- `Q` closes the app without inserting.

## See also

[`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)

## Examples

``` r
if (FALSE) { # \dontrun{
p <- browse_files()          # navigate, mark, press Q
files <- browse_files("data") # start in data/, return marked files
} # }
```
