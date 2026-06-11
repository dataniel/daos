# Extract CVR search hits as a tibble

Flattens the hits in a response from
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)
into a tibble with one row per document. Nested field names are reduced
to their last component and lowercased (e.g. `dokumenter.dokumentUrl`
becomes `dokumenturl`). Fields with several values per hit (typically
multiple documents) become multiple rows; single-valued fields are
recycled across them.

## Usage

``` r
cvr_hits(response)
```

## Arguments

- response:

  A parsed response list from
  [`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md).

## Value

A tibble with one row per document. Warns if the `cvrnummer` or
`dokumenturl` columns needed by
[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)
are missing.

## See also

[`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md),
[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)

Other cvr:
[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md),
[`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md),
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)

## Examples

``` r
if (FALSE) { # \dontrun{
hits <- cvr_query("12345678", "2024-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com") |>
  cvr_hits()
} # }
```
