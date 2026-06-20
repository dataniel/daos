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

test_that(".bf_rstring() quotes one path and vectorises several (one per line)", {
  expect_equal(daos:::.bf_rstring("C:/data/fil.csv"), '"C:/data/fil.csv"')
  expect_equal(daos:::.bf_rstring(c("C:/a", "C:/b")),
               'c(\n  "C:/a",\n  "C:/b"\n)')
  expect_equal(daos:::.bf_rstring(character()), "")
})

test_that(".bf_rstring() flips backslashes to forward slashes", {
  expect_equal(daos:::.bf_rstring("C:\\data\\fil.csv"), '"C:/data/fil.csv"')
})

test_that(".bf_readable() is TRUE for extensions the browser has a reader for", {
  expect_true(all(daos:::.bf_readable(c("a.csv", "b.XLSX", "c.parquet"))))
  expect_false(any(daos:::.bf_readable(c("a.pdf", "b.docx", "noext", "folder"))))
})

test_that(".bf_reader_for() returns the native reader call per extension", {
  expect_equal(daos:::.bf_reader_for("x.xlsx"), "readxl::read_xlsx")
  expect_equal(daos:::.bf_reader_for("data/y.PARQUET"), "arrow::read_parquet")
  expect_equal(daos:::.bf_reader_for("z.csv"), "readr::read_csv2")
  expect_true(is.na(daos:::.bf_reader_for("x.pdf")))
})

test_that(".bf_sheet_var() makes valid, unique R names", {
  expect_equal(daos:::.bf_sheet_var(c("Salg", "Budget 2026", "2024", "Salg")),
               c("salg", "budget_2026", "ark_2024", "salg_1"))
})

test_that(".bf_sheet_expr() reads one sheet inline and several as objects", {
  expect_equal(daos:::.bf_sheet_expr("C:\\data\\fil.xlsx", "Salg"),
               'readxl::read_excel("C:/data/fil.xlsx", sheet = "Salg")')
  norm  <- function(x) gsub(" +", " ", x)
  lines <- strsplit(daos:::.bf_sheet_expr("data/fil.xlsx", c("A", "Budget")), "\n")[[1]]
  expect_equal(norm(lines[1]), 'a <- readxl::read_excel("data/fil.xlsx", sheet = "A")')
  expect_equal(norm(lines[2]), 'budget <- readxl::read_excel("data/fil.xlsx", sheet = "Budget")')
  expect_equal(daos:::.bf_sheet_expr("x.xlsx", character()), "")
})

test_that(".bf_reader_expr() reads one file inline with its native reader", {
  expect_equal(daos:::.bf_reader_expr("C:\\data\\fil.parquet"),
               'arrow::read_parquet("C:/data/fil.parquet")')
  expect_equal(daos:::.bf_reader_expr("data/x.csv"),
               'readr::read_csv2("data/x.csv")')
})

test_that(".bf_reader_expr() maps over several files of one type", {
  paths <- c("data/a.parquet", "data/b.parquet")
  expect_equal(
    daos:::.bf_reader_expr(paths),
    'my_paths <- c(\n  "data/a.parquet",\n  "data/b.parquet"\n)\n\nlapply(my_paths, arrow::read_parquet)')
  # map = "purrr" swaps the iterator, nothing else
  expect_true(grepl("purrr::map(my_paths, arrow::read_parquet)",
                    daos:::.bf_reader_expr(paths, map = "purrr"), fixed = TRUE))
})

test_that(".bf_reader_expr() gives one named read per file for mixed types", {
  norm  <- function(x) gsub(" +", " ", x)
  lines <- strsplit(daos:::.bf_reader_expr(c("data/a.parquet", "data/b.csv")), "\n")[[1]]
  expect_equal(norm(lines[1]), 'a <- arrow::read_parquet("data/a.parquet")')
  expect_equal(norm(lines[2]), 'b <- readr::read_csv2("data/b.csv")')
})

test_that(".bf_match() globs, falls back to substring, and keeps all when empty", {
  files <- c("iris_2026.tsv", "iris_2025.tsv", "notes.txt")
  expect_equal(daos:::.bf_match(files, "*_2026*.tsv"), c(TRUE, FALSE, FALSE))
  expect_equal(daos:::.bf_match(files, "iris"), c(TRUE, TRUE, FALSE))   # substring
  expect_equal(daos:::.bf_match(files, "IRIS"), c(TRUE, TRUE, FALSE))   # case-insensitive
  expect_equal(daos:::.bf_match(files, ""), c(TRUE, TRUE, TRUE))        # empty -> all
  expect_equal(daos:::.bf_match(files, NULL), c(TRUE, TRUE, TRUE))
})

test_that(".bf_common_dir() finds the deepest shared directory", {
  expect_equal(daos:::.bf_common_dir(c("C:/a/b/x.tsv", "C:/a/b/y.tsv")), "C:/a/b")
  expect_equal(daos:::.bf_common_dir(c("C:/a/b/x.tsv", "C:/a/c/y.tsv")), "C:/a")
  expect_equal(daos:::.bf_common_dir("C:/a/x.tsv"), "C:/a")          # single -> own dir
  expect_equal(daos:::.bf_common_dir(c("C:/a/x.tsv", "D:/a/y.tsv")), "") # diff drive
})

test_that(".bf_reader_expr() breaks out base_dir for a single file too", {
  expect_equal(
    daos:::.bf_reader_expr("C:/demo/iris3.tsv", base = "C:/demo"),
    'base_dir <- "C:/demo"\n\nreadr::read_tsv(paste0(base_dir, "/iris3.tsv"))')
})

test_that(".bf_rstring() factors a base_dir when given one", {
  expect_equal(
    daos:::.bf_rstring(c("C:/demo/a.tsv", "C:/demo/b.tsv"), base = "C:/demo"),
    'c(\n  paste0(base_dir, "/a.tsv"),\n  paste0(base_dir, "/b.tsv")\n)')
})

test_that(".bf_rstring() keys elements by file name when named", {
  expect_equal(
    daos:::.bf_rstring(c("C:/demo/iris3.tsv", "C:/demo/iris2.tsv"), named = TRUE),
    'c(\n  iris3 = "C:/demo/iris3.tsv",\n  iris2 = "C:/demo/iris2.tsv"\n)')
  # a single path is never named
  expect_equal(daos:::.bf_rstring("C:/demo/iris3.tsv", named = TRUE),
               '"C:/demo/iris3.tsv"')
})

test_that(".bf_reader_expr() names the my_paths vector when asked", {
  out <- daos:::.bf_reader_expr(c("C:/demo/iris3.tsv", "C:/demo/iris2.tsv"),
                                named = TRUE)
  expect_true(grepl('iris3 = "C:/demo/iris3.tsv"', out, fixed = TRUE))
  expect_true(grepl("lapply(my_paths, readr::read_tsv)", out, fixed = TRUE))
})

test_that(".bf_reader_expr() can break out a shared base_dir", {
  paths <- c("C:/demo/iris3.tsv", "C:/demo/iris2.tsv")
  expect_equal(
    daos:::.bf_reader_expr(paths, base = "C:/demo"),
    paste0('base_dir <- "C:/demo"\n\n',
           'my_paths <- c(\n  paste0(base_dir, "/iris3.tsv"),\n',
           '  paste0(base_dir, "/iris2.tsv")\n)\n\n',
           'lapply(my_paths, readr::read_tsv)'))
})

test_that(".bf_expr() factors base_dir for plain and reader output", {
  d <- file.path(tempfile("bfb")); dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  fwd <- function(p) gsub("\\\\", "/", p)
  a <- file.path(d, "a.tsv"); writeLines("x", a)
  b <- file.path(d, "b.tsv"); writeLines("x", b)
  base <- fwd(normalizePath(d, winslash = "/"))

  # plain (no reader): bare vector with base_dir factored out
  plain <- daos:::.bf_expr(c(a, b), FALSE, base_on = TRUE)
  expect_true(grepl(sprintf('base_dir <- "%s"', base), plain, fixed = TRUE))
  expect_true(grepl('paste0(base_dir, "/a.tsv")', plain, fixed = TRUE))
  # reader: base_dir plus the mapped read
  rd <- daos:::.bf_expr(c(a, b), TRUE, base_on = TRUE)
  expect_true(grepl("lapply(my_paths, readr::read_tsv)", rd, fixed = TRUE))
  expect_true(grepl('paste0(base_dir, "/b.tsv")', rd, fixed = TRUE))
})

test_that(".bf_expr() in reader mode wraps only readable files", {
  d <- file.path(tempfile("bfx")); dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  fwd <- function(p) gsub("\\\\", "/", p)            # .bf_rstring uses forward slashes
  csv <- file.path(d, "a.csv"); writeLines("x", csv)
  pdf <- file.path(d, "b.pdf"); writeLines("x", pdf)
  sub <- file.path(d, "sub");   dir.create(sub)

  expect_equal(daos:::.bf_expr(csv, TRUE), sprintf('readr::read_csv2("%s")', fwd(csv)))
  # an unreadable file or a folder falls back to a bare path
  expect_equal(daos:::.bf_expr(pdf, TRUE), sprintf('"%s"', fwd(pdf)))
  expect_equal(daos:::.bf_expr(sub, TRUE), sprintf('"%s"', fwd(sub)))
  # mixed: only the csv is wrapped, pdf and folder dropped
  expect_equal(daos:::.bf_expr(c(csv, pdf, sub), TRUE),
               sprintf('readr::read_csv2("%s")', fwd(csv)))
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
