# write_ta() errors on character values that would not read back

    Code
      write_ta(df, path)
    Condition
      Error in `write_ta()`:
      ! Cannot write 3 values so that `read_ta()` reads them back unchanged:
      x nrnr, row 1: "1234567" is 7 characters, the field holds 5.
      x nrnr, row 2: "" is empty and would read back as NA.
      x nrnr, row 3: " 12" has leading or trailing spaces, which read_ta() trims.

# write_ta() errors on numbers it cannot write exactly in the field

    Code
      write_ta(df, path)
    Condition
      Error in `write_ta()`:
      ! Cannot write 3 values so that `read_ta()` reads them back unchanged:
      x eng, row 1: 123456789012 needs more than 11 characters to be exact.
      x eng, row 2: 0.33333333333333331 needs more than 11 characters to be exact.
      x eng, row 3: 0.30000000000000004 needs more than 11 characters to be exact.

