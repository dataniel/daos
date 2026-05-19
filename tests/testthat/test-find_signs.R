test_that("find_signs() finds the correct sign combination", {
  # Only one solution: 7 - 3 = 4 (i.e. signs +1, -1)
  df <- data.frame(
    label = c("a", "b", "total"),
    value = c(7, 3, 4)
  )
  result <- find_signs(df, label, value, total_label = "total")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  signed_values <- result$value[result$label != "total"]
  expect_equal(sum(signed_values), result$value[result$label == "total"])
})

test_that("find_signs() returns NULL (dropped) when no unique solution exists", {
  df <- data.frame(
    label = c("a", "b", "total"),
    value = c(1, 1, 99)
  )
  result <- find_signs(df, label, value, total_label = "total")
  expect_equal(nrow(result), 0)
})

test_that("find_signs() respects positive/negative constraints", {
  df <- data.frame(
    label = c("revenue", "costs", "total"),
    value = c(100, 60, 40)
  )
  result <- find_signs(df, label, value,
                       total_label = "total",
                       positive = "revenue",
                       negative = "costs")
  expect_equal(result$value[result$label == "revenue"],  100)
  expect_equal(result$value[result$label == "costs"],   -60)
})
