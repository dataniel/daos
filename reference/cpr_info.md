# Extract information from Danish CPR numbers

Vectorised extraction of birth date, age, sex, sequential number, and
validity indicators from Danish CPR (Civil Person Register) numbers.
Returns the original data frame with the requested columns appended.

## Usage

``` r
cpr_info(
  data,
  cpr_col,
  add = c("bday", "age", "sex", "pnum", "mod11", "valid"),
  ref_date = Sys.Date()
)
```

## Arguments

- data:

  A tibble or data frame.

- cpr_col:

  Name of the CPR column (unquoted).

- add:

  Which info types to add. Either:

  - An **unnamed** character vector, e.g. `c("bday", "age")` — uses the
    type names as column names.

  - A **named** character vector, e.g.
    `c(birth_date = "bday", years_old = "age")` — left-hand side becomes
    the column name, right-hand side is the type. Default: all six
    types.

- ref_date:

  Reference date for age calculation. Accepts a `Date` object or an
  ISO-format string (`"YYYY-MM-DD"`). Default:
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

## Value

The original data frame with the requested columns appended.

## Details

**Supported info types** (`add` values):

|           |           |                                                |
|-----------|-----------|------------------------------------------------|
| Type      | Output    | Description                                    |
| `"bday"`  | Date      | Date of birth                                  |
| `"age"`   | integer   | Age in whole years at `ref_date`               |
| `"sex"`   | character | `"mand"` (male) or `"kvinde"` (female)         |
| `"pnum"`  | integer   | Sequential (running) number (digits 7–10)      |
| `"mod11"` | logical   | Modulus-11 check (weights 4,3,2,7,6,5,4,3,2,1) |
| `"valid"` | logical   | Format valid *and* birth date parseable        |

**Century detection** follows the official CPR Register rules based on
digit 7 and the two-digit year component.

**Input tolerance:** dashes and spaces are stripped automatically.
Nine-digit numbers are zero-padded on the left (recovering values that
lost a leading zero in Excel).

## Examples

``` r
df <- data.frame(
  pnr = c("1111111118", "111111-1118", "111111118"),
  stringsAsFactors = FALSE
)

# Default: add all columns
cpr_info(df, pnr)
#>           pnr       bday age    sex pnum mod11 valid
#> 1  1111111118 1911-11-11 114 kvinde 1118  TRUE  TRUE
#> 2 111111-1118 1911-11-11 114 kvinde 1118  TRUE  TRUE
#> 3   111111118 1911-11-01 114 kvinde 1118 FALSE  TRUE

# Custom column names:
cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#>           pnr birth_date years_old
#> 1  1111111118 1911-11-11       114
#> 2 111111-1118 1911-11-11       114
#> 3   111111118 1911-11-01       114

# Unnamed — uses type names directly:
cpr_info(df, pnr, add = c("bday", "sex"))
#>           pnr       bday    sex
#> 1  1111111118 1911-11-11 kvinde
#> 2 111111-1118 1911-11-11 kvinde
#> 3   111111118 1911-11-01 kvinde
```
