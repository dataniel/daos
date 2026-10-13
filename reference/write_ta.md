# Write a Greenlandic TA file

Writes a data frame to a Greenlandic TA fixed-width file. Writes the
nine columns `nrnr`, `trans`, `brch`, `bas`, `eng`, `det`, `afg`,
`moms`, and `kbx`, in the positions
[`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)
reads them from.

## Usage

``` r
write_ta(x, path)
```

## Arguments

- x:

  A data frame with exactly the columns `nrnr`, `trans`, `brch`, `bas`,
  `eng`, `det`, `afg`, and `kbx`. `moms` is optional; if absent it is
  derived automatically (see Details). Any other columns cause an error.

- path:

  Path to write to.

## Value

`path`, invisibly.

## Details

If `moms` is absent from `x`, it is derived automatically: `NA` for rows
where `trans` is `"0100"` or `"0700"` (no VAT in Greenland), `0`
otherwise.

The file is guaranteed to read back through
[`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)
unchanged. A fixed-width file has no delimiters, so a value wider than
its field does not fail: it pushes every following field out of
position, and the file still parses, just into the wrong columns.
`write_ta()` therefore refuses to write anything it cannot write
exactly, and lists every offending value at once.

- Numbers are written with the fewest decimals that reproduce the value
  exactly, so whole numbers are written without decimals. A number whose
  exact form is wider than its field is an error, never rounded.

- Character values are left-aligned. Because
  [`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md)
  trims whitespace and reads blank fields as `NA`, values that are too
  long, empty, or start or end with a space are errors.

- `NA` is written as a blank field.

|                          |       |
|--------------------------|-------|
| Column                   | Width |
| nrnr                     | 5     |
| trans                    | 6     |
| brch                     | 4     |
| bas                      | 13    |
| eng, det, afg, moms, kbx | 11    |

## Examples

``` r
if (FALSE) { # \dontrun{
write_ta(df, "ta.file")
} # }
```
