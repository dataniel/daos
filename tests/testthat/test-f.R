test_that("f() interpolates expressions", {
  name <- "world"
  expect_equal(f("Hello, {name}!"), "Hello, world!")
  expect_equal(f("{1 + 1}"), "2")
})

test_that("f() expands vectors to multiple strings", {
  expect_equal(f("item_{1:3}"), c("item_1", "item_2", "item_3"))
})
