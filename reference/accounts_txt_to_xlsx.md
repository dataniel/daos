# Parse formatted text files and export to Excel

Reads all `.txt` files in a directory, parses them according to a
specific layout used for manually formatted financial statements, and
exports the result as an Excel file. Messages report how many files were
collected and a summary when done. All companies are validated before
any output is written; formatting problems abort with a combined message
listing every offending company along with the file and the offending
lines or elements.

## Usage

``` r
accounts_txt_to_xlsx(txt_dir, out_file, year, min_spaces = 3)
```

## Arguments

- txt_dir:

  Path to the directory containing `.txt` files.

- out_file:

  Path to the output `.xlsx` file.

- year:

  The accounting year as a numeric scalar (e.g. `2024`).

- min_spaces:

  Minimum number of consecutive spaces used as field delimiter. Default
  `3`.

## Value

The parsed data as a tibble, invisibly.

## Details

**Text file format:**

Each line is either a *category line* or a *data line*:

- **Category line:** a single string with no field delimiter. Becomes
  the `note` column for all subsequent data lines.

- **Data line:** three fields separated by `min_spaces` or more
  consecutive spaces: (1) element name, (2) amount for `year`, (3)
  amount for `year - 1`.

Amounts must be in whole kroner (periods as thousands separators are
stripped automatically). If the previous year is absent, the third field
may be empty – it becomes `NA`.

Appending ` statnatio` to a category line negates all values in that
category (useful when costs appear with a positive sign in notes).

File names are used as identifiers in the `cvr` column. A trailing
`_spec` suffix is stripped automatically (e.g. `12345678_spec.txt` -\>
`12345678`).

## Examples

``` r
if (FALSE) { # \dontrun{
accounts_txt_to_xlsx("data/txt", "data/output.xlsx", year = 2024)
} # }
```
