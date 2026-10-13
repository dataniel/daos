# Read a Greenlandic TA file in the new layout

Reads a Greenlandic TA file in the new 140-character layout, the one
[`write_ta2()`](https://dataniel.github.io/daos/reference/write_ta2.md)
writes. For the old layout, use
[`read_ta()`](https://dataniel.github.io/daos/reference/read_ta.md).

## Usage

``` r
read_ta2(path)
```

## Arguments

- path:

  Path to the TA file.

## Value

A tibble with the nine columns above.

## Details

Both layouts are kept during the transition to the new TA system, and
afterwards so old files can still be read. The `2` marks the new layout,
not a newer version of the same function. An old-layout file is shorter
than 140 characters per line and is therefore rejected rather than read
into the wrong columns.

Column positions (1-based characters):

|        |           |
|--------|-----------|
| Column | Positions |
| nrnr   | 1–6       |
| trans  | 17–21     |
| brch   | 31–35     |
| bas    | 36–60     |
| eng    | 61–76     |
| det    | 77–92     |
| afg    | 93–108    |
| moms   | 109–124   |
| kbx    | 125–140   |

Fields are trimmed, and blank fields are read as `NA`. Columns `nrnr`,
`trans`, and `brch` are read as character; the rest as double. A numeric
field that is not a number is an error, not a silent `NA`.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- read_ta2("ta.file")
} # }
```
