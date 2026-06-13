# The app itself is GUI/Shiny and not tested here; these cover the pure
# building blocks with a temporary directory.

make_tree <- function() {
  root <- file.path(tempfile("bf"))
  dir.create(root)
  dir.create(file.path(root, "zeta"))
  dir.create(file.path(root, "alpha"))
  writeLines("x", file.path(root, "notes.txt"))
  writeLines("y", file.path(root, "Apple.csv"))
  root
}

test_that(".bf_list() lists directories first, then files, alphabetically", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE))
  out <- daos:::.bf_list(root)
  expect_equal(out$name, c("alpha", "zeta", "Apple.csv", "notes.txt"))
  expect_equal(out$type, c("d", "d", "f", "f"))
})

test_that(".bf_list() returns full forward-slash paths", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE))
  out <- daos:::.bf_list(root)
  expect_true(all(grepl("/", out$full, fixed = TRUE)))
  expect_false(any(grepl("\\", out$full, fixed = TRUE)))
  expect_true(all(basename(out$full) == out$name))
})

test_that(".bf_list() returns an empty tibble for a missing directory", {
  out <- daos:::.bf_list(file.path(tempdir(), "does-not-exist-bf"))
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
  expect_equal(names(out), c("name", "type", "full", "size", "mtime"))
})

test_that(".bf_rstring() quotes one path and vectorises several", {
  expect_equal(daos:::.bf_rstring("C:/data/fil.csv"), '"C:/data/fil.csv"')
  expect_equal(daos:::.bf_rstring(c("C:/a", "C:/b")), 'c("C:/a", "C:/b")')
  expect_equal(daos:::.bf_rstring(character()), "")
})

test_that(".bf_rstring() flips backslashes to forward slashes", {
  expect_equal(daos:::.bf_rstring("C:\\data\\fil.csv"), '"C:/data/fil.csv"')
})

test_that(".bf_is_root() detects filesystem roots", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE))
  expect_false(daos:::.bf_is_root(root))
  if (.Platform$OS.type == "windows") {
    expect_true(daos:::.bf_is_root("C:/"))
  } else {
    expect_true(daos:::.bf_is_root("/"))
  }
})

test_that(".bf_roots() returns existing roots", {
  roots <- daos:::.bf_roots()
  expect_true(length(roots) >= 1)
  expect_true(all(vapply(roots, dir.exists, logical(1))))
})

test_that(".bf_size() formats bytes readably", {
  expect_equal(daos:::.bf_size(0), "0 B")
  expect_equal(daos:::.bf_size(512), "512 B")
  expect_equal(daos:::.bf_size(2048), "2.0 KB")
  expect_equal(daos:::.bf_size(NA), "")
})
