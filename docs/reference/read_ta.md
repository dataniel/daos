# Read a Greenlandic TA file

Reads a Greenlandic TA file. Supports current prices (L), constant
prices (F), and prior-year prices (D) file types.

## Usage

``` r
read_ta(ta)
```

## Arguments

- ta:

  Path to the TA file.

## Value

A tibble with the columns described above.

## Details

Column positions (0-based byte offsets):

|        |       |     |
|--------|-------|-----|
| Column | Start | End |
| nrnr   | 0     | 5   |
| trans  | 6     | 12  |
| brch   | 13    | 17  |
| bas    | 18    | 32  |
| eng    | 33    | 45  |
| det    | 46    | 58  |
| afg    | 59    | 71  |
| moms   | 72    | 84  |
| kbx    | 85    | 97  |
| prim   | 98    | 103 |
| afstm  | 104   | 107 |
| fval   | 108   | end |

Columns `nrnr`, `trans`, `brch`, `afstm`, and `fval` are read as
character; all others as double.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- read_ta("ta.file")
} # }
```
