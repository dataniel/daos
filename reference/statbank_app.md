# Interactive explorer for the Greenland Statbank

Launches a Shiny app for working with the Greenland Statbank
(bank.stat.gl). The app guides the user through three steps: find a
table (search the titles, or walk the subject tree in a three-column
browser – parent, current, and a live preview of the item under the
cursor – that also responds to `h`/`j`/`k`/`l` and the arrow keys),
choose values for each variable, and fetch the data. The result is shown
as a table and a plot, and the app always shows the
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)
call that reproduces the selection, so a click-built query can be pasted
straight into a script.

## Usage

``` r
statbank_app(bank = "gl", lang = NULL)
```

## Arguments

- bank:

  Statbank to open: `"gl"` (Greenland, the default) or `"fo"` (the Faroe
  Islands). The bank can also be switched inside the app.

- lang:

  Language of titles and labels, or `NULL` (default) for the bank's own
  default (Danish for Greenland, Faroese for the Faroe Islands).

## Value

The last fetched dataset, invisibly (`NULL` if nothing was fetched).

## Details

Time variables, and numeric variables with many values (such as age),
are selected with from/to dropdowns. Other variables open a popup with a
searchable checkbox list, select/deselect-all shortcuts, and a running
count; an empty selection means all values. The popup lists the values
in the table's own (PX) order, with a link to sort them alphabetically
instead.

Built as a programming aid, the settings under step 3 default to the
code-first shape from
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md):
coded column names (snake-cased), coded cells, and type conversion. Pill
toggles switch column names and cells between codes and texts (or
"both", which adds a `<column>_txt` column with the labels), turn
snake-casing off, or paste the full base URL into the generated call so
it can be rebuilt by hand. The language chooser at the top picks the
language of titles, labels, and texts (Greenland offers Danish,
Kalaallisut, and English; the Faroe Islands offer Faroese and English).

Fetched data can be downloaded as a formatted Excel file (via
[`write_excel()`](https://dataniel.github.io/daos/reference/write_excel.md)
when `openxlsx2` is installed, otherwise CSV). Before download, a pivot
chooser can spread one variable across the columns – typically time, the
layout spreadsheet users want – with the preview updating to match. The
R code – prefixed `daos::` so it runs without
[`library(daos)`](https://dataniel.github.io/daos) – can be inserted
into the active RStudio document with "Inds og luk" (which closes the
app) or copied; a toggle lifts the variable selections into a spliced
`my_query` list (`!!!my_query`). The graph is interactive when `plotly`
is installed: with many series only the largest are highlighted and the
rest greyed, but every line is identifiable on hover. Pressing `Q`
closes the app and returns the last fetched dataset, so
`df <- statbank_app()` also works as a data-fetching workflow.

The app covers both the Greenland statbank (the default) and the Faroese
one. The bank chooser sits one level above the subject root: press `h`
(or click the breadcrumb) at the root to switch bank, which reloads the
tree in that bank's default language.

The table list is fetched when the app starts (one request per folder in
the tree) and reused for the rest of the R session.

## See also

[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md),
[`statbank_search()`](https://dataniel.github.io/daos/reference/statbank_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
statbank_app()
} # }
```
