# Read an XBRL file

Parses an XBRL XML document and returns a tidy tibble with facts joined
to their context and unit information.

## Usage

``` r
read_xbrl(path, encoding = "UTF-8")
```

## Arguments

- path:

  Path to the XBRL file (`.xml` or similar).

- encoding:

  Character encoding of the file. Defaults to `"UTF-8"`.

## Value

A [`tibble`](https://rdrr.io/pkg/tibble/man/tibble.html) with one row
per fact and columns: `elementid`, `contextid`, `fact`, `unitid`,
`decimals`, `startdate`, `enddate`, `instant`, `explicit_member`,
`unit`.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- read_xbrl("report.xml")
} # }
```
