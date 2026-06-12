# Convert PDF files to text files

Reads all PDF files in a directory, extracts their text content using
[`pdftools::pdf_text()`](https://docs.ropensci.org/pdftools//reference/pdftools.html),
and writes one `.txt` file per PDF to the output directory. A progress
bar is shown while converting; messages are only emitted for skipped
PDFs, plus a summary when done.

## Usage

``` r
accounts_pdf_to_txt(pdf_dir, txt_dir, overwrite = FALSE)
```

## Arguments

- pdf_dir:

  Path to the directory containing PDF files.

- txt_dir:

  Path to the directory where text files will be written. Created
  automatically if it does not exist.

- overwrite:

  If `FALSE` (default), the function aborts when any of the `.txt` files
  it would write already exist. Set to `TRUE` to replace them.

## Value

Invisibly, a character vector of paths to the written `.txt` files
(skipped PDFs are not included).

## Details

PDFs with no extractable text (blank or whitespace only, typically
scanned/photo-printed annual reports) are skipped with a warning
message; no `.txt` file is written for them.

## Examples

``` r
if (FALSE) { # \dontrun{
accounts_pdf_to_txt("data/pdf", "data/txt")
} # }
```
