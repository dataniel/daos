# write_ta2() errors on values that would not read back

    Code
      write_ta2(df, path)
    Condition
      Error in `write_ta2()`:
      ! Cannot write 4 values so that `read_ta2()` reads them back unchanged:
      x nrnr, row 1: "1234567" is 7 characters, the field holds 6.
      x nrnr, row 2: "" is empty and would read back as NA.
      x nrnr, row 3: " 12" has leading or trailing spaces, which read_ta2() trims.
      x eng, row 1: 0.33333333333333331 needs more than 16 characters to be exact.

