# Extracted from test-read_workbook.R:163

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "daos", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
skip_if_not_installed("openxlsx2")
skip_if_not_installed("readxl")
skip_if_not_installed("xml2")

# test -------------------------------------------------------------------------
ref <- daos:::.parse_defined_ref(c(
    "'Sheet 1'!$B$3:$F$40", "Data!$A$1", "'It''s'!$B:$C", "Data!$3:$5",
    "0.25", "Data!$A$1:$B$2,Data!$D$1:$E$2", "#REF!", "SUM(Data!$A:$A)"
  ))
expect_equal(ref$sheet, c("Sheet 1", "Data", "It's", "Data", NA, NA, NA, NA))
