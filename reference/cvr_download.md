# Download CVR documents

Downloads the documents listed in a tibble from
[`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md),
one file per row, named by CVR number (repeated CVR numbers get a `_2`,
`_3`, ... suffix). A delay between requests keeps the load on the API
polite.

## Usage

``` r
cvr_download(hits, path, sleep = 3, overwrite = FALSE)
```

## Arguments

- hits:

  A tibble with `cvrnummer` and `dokumenturl` columns, typically from
  [`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md).

- path:

  Directory to download into. Created automatically if it does not
  exist.

- sleep:

  Seconds to wait between downloads. Must be at least 1; the default of
  3 matches the API's expectations for bulk retrieval.

- overwrite:

  If `FALSE` (default), the function aborts when any of the files it
  would write already exist. Set to `TRUE` to replace them.

## Value

Invisibly, a character vector of paths to the downloaded files (failed
downloads are not included).

## See also

[`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md),
[`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md),
[`accounts_pdf_to_txt()`](https://dataniel.github.io/daos/reference/accounts_pdf_to_txt.md)
for the next step of the workflow.

Other cvr:
[`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md),
[`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
cvr_query("12345678", "2024-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com") |>
  cvr_hits() |>
  cvr_download("data/pdf")
} # }
```
