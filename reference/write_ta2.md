# Write a Greenlandic TA file in the new layout

Writes a data frame to a Greenlandic TA fixed-width file in the new
140-character layout, the one
[`read_ta2()`](https://dataniel.github.io/daos/reference/read_ta2.md)
reads. For the old layout, use
[`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md).

## Usage

``` r
write_ta2(x, path)
```

## Arguments

- x:

  A data frame with exactly the columns `nrnr`, `trans`, `brch`, `bas`,
  `eng`, `det`, `afg`, and `kbx`. `moms` is optional; if absent it is
  derived automatically. Any other columns cause an error.

- path:

  Path to write to.

## Value

`path`, invisibly.

## Details

If `moms` is absent from `x`, it is derived automatically: `NA` for rows
where `trans` is `"0100"` or `"0700"` (no VAT in Greenland), `0`
otherwise.

Both layouts are kept during the transition to the new TA system, and
afterwards so old files can still be produced. The `2` marks the new
layout, not a newer version of the same function.

The file is guaranteed to read back through
[`read_ta2()`](https://dataniel.github.io/daos/reference/read_ta2.md)
unchanged, by the same rules as
[`write_ta()`](https://dataniel.github.io/daos/reference/write_ta.md): a
value that does not fit its field is an error, never truncated or
rounded, and every offending value is listed at once. Whole numbers are
written without decimals; other numbers with the fewest decimals that
reproduce them exactly. `NA` is written as a blank field.

Character fields are left-aligned, numeric fields right-aligned (1-based
character positions):

|         |           |       |
|---------|-----------|-------|
| Column  | Positions | Width |
| nrnr    | 1–6       | 6     |
| *blank* | 7–16      | 10    |
| trans   | 17–21     | 5     |
| *blank* | 22–30     | 9     |
| brch    | 31–35     | 5     |
| bas     | 36–60     | 25    |
| eng     | 61–76     | 16    |
| det     | 77–92     | 16    |
| afg     | 93–108    | 16    |
| moms    | 109–124   | 16    |
| kbx     | 125–140   | 16    |

## Examples

``` r
if (FALSE) { # \dontrun{
write_ta2(df, "ta.file")
} # }
```
