# Write a Greenlandic TA file

Writes a data frame to a Greenlandic TA fixed-width file. Writes the
nine columns `nrnr`, `trans`, `brch`, `bas`, `eng`, `det`, `afg`,
`moms`, and `kbx`. Numeric columns are written without decimal places;
character columns are left-aligned in their field.

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

## Examples

``` r
if (FALSE) { # \dontrun{
write_ta(df, "ta.file")
} # }
```
