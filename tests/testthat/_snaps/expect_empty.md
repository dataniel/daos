# failure messages report the row count and preview rows

    Code
      expect_empty(df, warn_msg = "Bad rows")
    Condition
      Warning in `expect_empty()`:
      Bad rows
      i 3 rows found:
             id name
          <dbl> <chr>
        1    NA a
        2     2 b
        3     3 <NA>

