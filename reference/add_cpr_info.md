# Add information derived from Danish CPR numbers

Vectorised derivation of birth date, age, sex, and validity indicators
from Danish CPR (Civil Person Register) numbers. Returns the original
data frame with the requested columns appended.

## Usage

``` r
add_cpr_info(
  data,
  cpr_col,
  add = c("bday", "age", "sex", "mod11", "valid"),
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
    the column name, right-hand side is the type. Default: all five
    types.

- ref_date:

  Reference date for age calculation. Accepts a `Date` object or an
  ISO-format string (`"YYYY-MM-DD"`). Default:
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

## Value

The original data frame with the requested columns appended.

## Details

**Supported info types** (`add` values):

|  |  |  |
|----|----|----|
| Type | Output | Description |
| `"bday"` | Date | Date of birth |
| `"age"` | integer | Age in whole years at `ref_date` |
| `"sex"` | integer | `1` (male, odd last digit) or `0` (female, even last digit) |
| `"mod11"` | logical | Modulus-11 check (weights 4,3,2,7,6,5,4,3,2,1) |
| `"valid"` | logical | Format valid *and* the encoded birth date is a real calendar date |

**What `valid` means – and what it deliberately does not:**
`valid = TRUE` requires exactly two things: the cleaned value is ten
digits, and those digits encode a real calendar date under the official
century rules. **The modulus-11 check is *not* part of `valid`.** Since
2007 the CPR office has assigned numbers *without* modulus-11 control,
because some birth dates have run out of mod-11-compatible sequence
numbers; cpr.dk states that these are "fuldt ud gyldige personnumre" (so
far assigned to persons born on certain 1 January dates between 1960 and
the 1990s). A failed mod-11 therefore does not make a CPR number invalid
– validators that reject on mod-11 wrongly reject real, living people.
The check is still reported separately as `mod11`, because it remains a
useful data-quality signal: a high failure rate in older data suggests
keying errors. Note also that the official assignment series start at
sequence number 0001, so `0000` never occurs in practice; it is not
rejected here, since the date check is the documented criterion.

**Century detection** follows the official CPR rules based on digit 7
and the two-digit year component (see the table in the source code).

**Input tolerance:** the CPR column is standardised with
[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)
– dashes and spaces are stripped and nine-digit numbers are zero-padded
on the left (recovering values that lost a leading zero in Excel). The
CPR column in the returned data frame is always returned in the
standardised 10-digit format `xxxxxxxxxx`.

**Implementation note:** the function is pure vectorised arithmetic –
one string-to-number conversion, digits peeled into an n-by-10 matrix,
the mod-11 checksum as a single matrix product, and birth dates
constructed directly as epoch day counts (no date-string parsing). It
scales linearly to millions of rows.

## References

CPR-kontoret, *Personnummeret i CPR-systemet* (1 July 2008),
<https://cdn2.gopublic.dk/cpr/media/12066/personnummeret-i-cpr.pdf>;
*Opbygning af CPR-nummeret*,
<https://www.cpr.dk/cpr-systemet/opbygning-af-cpr-nummeret>;
*Personnumre uden kontrolciffer (modulus 11 kontrol)*,
<https://www.cpr.dk/cpr-systemet/personnumre-uden-kontrolciffer-modulus-11-kontrol>.

## See also

[`clean_cpr()`](https://dataniel.github.io/daos/reference/clean_cpr.md)

## Examples

``` r
df <- data.frame(
  pnr = c("1111111118", "111111-1118", "111111118"),
  stringsAsFactors = FALSE
)

# Default: add all columns
add_cpr_info(df, pnr)
#>          pnr       bday age sex mod11 valid
#> 1 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 2 1111111118 1911-11-11 114   0  TRUE  TRUE
#> 3 0111111118 1911-11-01 114   0 FALSE  TRUE

# Custom column names:
add_cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#>          pnr birth_date years_old
#> 1 1111111118 1911-11-11       114
#> 2 1111111118 1911-11-11       114
#> 3 0111111118 1911-11-01       114

# Unnamed — uses type names directly:
add_cpr_info(df, pnr, add = c("bday", "sex"))
#>          pnr       bday sex
#> 1 1111111118 1911-11-11   0
#> 2 1111111118 1911-11-11   0
#> 3 0111111118 1911-11-01   0
```
