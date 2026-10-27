# failure messages report the row count and preview rows

    Code
      expect_empty(df, warn_msg = "Bad rows")
    Condition
      Warning in `expect_empty()`:
      Bad rows
      i 3 rows found:
        id = NA, name = "a"
        id = 2, name = "b"
        id = 3, name = NA

