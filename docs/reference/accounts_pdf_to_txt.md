# Convert PDF files to text files

Reads all PDF files in a directory, extracts their text content using
[`pdftools::pdf_text()`](https://rdrr.io/pkg/pdftools/man/pdftools.html),
and writes one `.txt` file per PDF to the output directory.

## Usage

``` r
accounts_pdf_to_txt(pdf_dir, txt_dir)
```

## Arguments

- pdf_dir:

  Path to the directory containing PDF files.

- txt_dir:

  Path to the directory where text files will be written. Created
  automatically if it does not exist.

## Value

Invisibly, a character vector of paths to the written `.txt` files.

## Examples

``` r
if (FALSE) { # \dontrun{
accounts_pdf_to_txt("data/pdf", "data/txt")
} # }
```
