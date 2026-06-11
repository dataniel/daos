# Responsible use of the CVR functions

The `cvr_*` functions fetch published annual reports from
Erhvervsstyrelsens distribution service. The service is official, free,
and built precisely for system-to-system access – annual reports are
public documents by law. Using it is legitimate; using it *well* is a
matter of a few habits, which is what this article is about.

## The pipeline

Four functions, one step each: build the query, send it, extract the
hits, download the documents. Requires `curl` and `jsonlite`.

``` r

cvr_query(
  cvr          = c("12345678", "87654321"),
  enddate_from = "2024-01-01",
  enddate_to   = "2024-12-31"
) |>
  cvr_search(contact = "you@example.com") |>
  cvr_hits() |>
  cvr_download("data/pdf")
```

- [`cvr_query()`](https://dataniel.github.io/daos/reference/cvr_query.md)
  builds the Elasticsearch query (pure, no network). Matches by CVR
  number (max 1000 per query) and accounting-period end date.
- [`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)
  posts the query and returns the parsed response.
- [`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md)
  flattens the response into a tibble with one row per document
  (`cvrnummer`, `dokumenturl`, …).
- [`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)
  downloads the documents, named by CVR number.

Everything before
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)
is local; that line is the first real API call.

## Identify yourself

The `contact` argument is mandatory and is sent as the `User-Agent`
header. Erhvervsstyrelsen asks requests to identify the sender – use a
real email address you can be reached at. The function refuses to run
with an empty contact, but it cannot check that the address is honest;
that part is yours.

## Be polite about volume

Each hit is one published annual report, and its `dokumenter` array
typically holds several files (PDF, XML/XBRL, sometimes XHTML) – expect
roughly 3-5 document rows per company per year in the hits tibble.

The query selects *companies and periods*. Selecting which *documents*
to download is done in R, between
[`cvr_hits()`](https://dataniel.github.io/daos/reference/cvr_hits.md)
and
[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md):

``` r

hits <- hits |> dplyr::filter(dokumentmimetype == "application/pdf")
```

The arithmetic matters: 1000 companies for one year is ~1000 hits but
3000–5000 documents, which at the default `sleep = 3` is 2.5–4 hours of
downloading. Filtering to one mimetype first cuts it to ~1000 files
(under an hour). Always look at the hits tibble before you call
[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)
– it tells you exactly what you are about to fetch.

[`cvr_download()`](https://dataniel.github.io/daos/reference/cvr_download.md)
enforces a delay of at least 1 second between requests (default 3) and
guards existing files with an `overwrite` argument, so an accidental
rerun stops before re-downloading anything.

## Complete results: `scroll`

A single response holds at most `query$size` hits (default 2999).
[`cvr_search()`](https://dataniel.github.io/daos/reference/cvr_search.md)
warns if the response is full, since the result may then be truncated.
For large pulls – many companies across many years – use the scroll API
to fetch every matching hit in batches:

``` r

response <- cvr_query(many_cvrs, "2015-01-01", "2024-12-31") |>
  cvr_search(contact = "you@example.com", scroll = TRUE)
```

Note that `scroll` is about the *completeness of the search result*; it
does not reduce the number of documents you download afterwards.

## Test small first

Before a big pull, run the pipeline on a handful of companies and a
narrow date range, inspect the hits tibble, and only then scale up. If
you want to see the scroll mechanics work without load, force small
batches: `scroll = 2` on a query with a few hits walks through the whole
flow in a couple of requests.

## The legal frame

Annual reports are public by law, and the distribution service is the
channel Erhvervsstyrelsen provides for exactly this kind of retrieval.
Usage falls under the general terms for Danish open public data. The one
substantive restriction to know about is *reklamebeskyttelse*
(CVR-lovens paragraf 19): data on protected companies must not be used
for direct marketing. For statistical and analytical use of financial
statements, that restriction is irrelevant – but if your use case ever
drifts toward contacting the companies, check it.
