# read_ta2() rejects short lines, pointing to read_ta()

    Code
      read_ta2(path)
    Condition
      Error in `read_ta2()`:
      ! Lines 2 and 4 are shorter than the 140 characters of the TA layout.
      i Is this an old-layout file? Use `read_ta()` for those.

# read_ta2() errors on numeric fields that are not numbers

    Code
      read_ta2(path)
    Condition
      Error in `read_ta2()`:
      ! Cannot read 2 numeric fields:
      x eng, line 2: "1.2.3" is not a number.
      x kbx, line 2: "abc" is not a number.

