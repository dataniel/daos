flip <- function(x) gsub("\\\\", "/", x)

# .fix_windows_paths -------------------------------------------------------

test_that(".fix_windows_paths converts drive paths", {
  expect_equal(
    daos:::.fix_windows_paths("C:\\Users\\danie\\Documents"),
    "C:/Users/danie/Documents"
  )
})

test_that(".fix_windows_paths converts UNC paths", {
  expect_equal(
    daos:::.fix_windows_paths("\\\\server\\share\\file.txt"),
    "//server/share/file.txt"
  )
})

test_that(".fix_windows_paths handles path at end of string (no char doubling)", {
  expect_equal(
    daos:::.fix_windows_paths("C:\\Users\\danie\\Documents\\arkiv\\cv"),
    "C:/Users/danie/Documents/arkiv/cv"
  )
})

test_that(".fix_windows_paths only touches paths, not other backslashes", {
  input <- "use \\n for newline, but C:\\Users\\foo gets fixed"
  expect_equal(
    daos:::.fix_windows_paths(input),
    "use \\n for newline, but C:/Users/foo gets fixed"
  )
})

test_that(".fix_windows_paths handles multiple paths in one string", {
  input <- "C:\\foo\\bar and C:\\baz\\qux"
  expect_equal(
    daos:::.fix_windows_paths(input),
    "C:/foo/bar and C:/baz/qux"
  )
})

test_that(".fix_windows_paths leaves non-path text unchanged", {
  expect_equal(daos:::.fix_windows_paths("no paths here"), "no paths here")
})

# addin_paste_path core logic ----------------------------------------------

paste_path <- function(raw) {
  text  <- paste(raw, collapse = "\n")
  fixed <- gsub("\\\\", "/", text)
  paste0('"', fixed, '"')
}

test_that("paste_path flips backslashes and wraps in quotes", {
  expect_equal(
    paste_path("C:\\Users\\danie\\Documents"),
    '"C:/Users/danie/Documents"'
  )
})

test_that("paste_path handles path with no backslashes", {
  expect_equal(paste_path("C:/already/fixed"), '"C:/already/fixed"')
})

test_that("paste_path collapses multi-line clipboard content", {
  expect_equal(
    paste_path(c("C:\\foo\\bar", "C:\\baz\\qux")),
    '"C:/foo/bar\nC:/baz/qux"'
  )
})

# addin_flip_backslash core logic ------------------------------------------

test_that("flip() replaces all backslashes with forward slashes", {
  expect_equal(flip("C:\\Users\\danie"), "C:/Users/danie")
})

test_that("flip() handles text with no backslashes", {
  expect_equal(flip("C:/Users/danie"), "C:/Users/danie")
})

test_that("flip() replaces backslashes outside of Windows paths", {
  expect_equal(flip("foo\\bar\\baz"), "foo/bar/baz")
})

# .resolve_path_text core logic --------------------------------------------

test_that(".resolve_path_text returns an existing literal path as-is", {
  f <- withr::local_tempfile()
  writeLines("x", f)
  expect_equal(daos:::.resolve_path_text(f), f)
})

test_that(".resolve_path_text strips surrounding quotes from a literal path", {
  f <- withr::local_tempfile()
  writeLines("x", f)
  expect_equal(daos:::.resolve_path_text(paste0('"', f, '"')), f)
  expect_equal(daos:::.resolve_path_text(paste0("'", f, "'")), f)
})

test_that(".resolve_path_text evaluates an object holding a path", {
  f <- withr::local_tempfile()
  writeLines("x", f)
  e <- new.env()
  assign("p", f, envir = e)
  expect_equal(daos:::.resolve_path_text("p", envir = e), f)
})

test_that(".resolve_path_text evaluates a call returning a path", {
  d <- withr::local_tempdir()
  e <- new.env()
  assign("d", d, envir = e)
  expect_equal(
    daos:::.resolve_path_text('file.path(d, "a")', envir = e),
    file.path(d, "a")
  )
})

test_that(".resolve_path_text falls back to the unquoted literal", {
  expect_equal(daos:::.resolve_path_text("no_such_thing"), "no_such_thing")
})

test_that(".resolve_path_text returns NULL for blank text", {
  expect_null(daos:::.resolve_path_text("   "))
  expect_null(daos:::.resolve_path_text(""))
})

# .token_at_cursor core logic ----------------------------------------------

test_that(".token_at_cursor grabs the object name under the cursor", {
  line <- "x <- my_path"
  # cursor anywhere inside 'my_path' (cols 7..13)
  expect_equal(daos:::.token_at_cursor(line, 9), "my_path")
  # cursor just after the token
  expect_equal(daos:::.token_at_cursor(line, 13), "my_path")
})

test_that(".token_at_cursor captures an unquoted path including slashes", {
  line <- "C:/Users/danie/data.csv"
  expect_equal(daos:::.token_at_cursor(line, 5), "C:/Users/danie/data.csv")
})

test_that(".token_at_cursor stops the token at whitespace", {
  line <- "open  my_path  now"
  expect_equal(daos:::.token_at_cursor(line, 8), "my_path")
})

test_that(".token_at_cursor returns empty when the cursor is on whitespace", {
  expect_equal(daos:::.token_at_cursor("a   b", 3), "")
})

test_that(".token_at_cursor returns empty for an empty line", {
  expect_equal(daos:::.token_at_cursor("", 1), "")
})

# addin_text_to_vector core logic ------------------------------------------

make_vector_result <- function(text) {
  items <- strsplit(text, "\n")[[1]]
  items <- trimws(items)
  items <- items[nzchar(items)]
  paste0('c(\n', paste0('  "', items, '"', collapse = ",\n"), '\n)')
}

test_that("text-to-vector core produces correct R expression", {
  expect_equal(
    make_vector_result("a\nb\nc"),
    'c(\n  "a",\n  "b",\n  "c"\n)'
  )
})

test_that("text-to-vector core ignores empty lines", {
  expect_equal(
    make_vector_result("a\n\nb"),
    'c(\n  "a",\n  "b"\n)'
  )
})

test_that("text-to-vector core trims whitespace", {
  expect_equal(
    make_vector_result("  a  \n  b  "),
    'c(\n  "a",\n  "b"\n)'
  )
})
