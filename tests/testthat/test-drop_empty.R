empty_example <- function() {
  tibble::tibble(id = 1:4, score_a = c(1, NA, NA, 0),
                score_b = rep(NA_real_, 4), text = c("ok", "", " ", " kept "))
}

test_that("row selections ignore identifiers and retain every column", {
  df <- empty_example()
  expect_identical(drop_empty_rows(df), df)
  expect_identical(drop_empty_rows(df, starts_with("score_")), df[c(1, 4), ])
  expect_identical(drop_empty_rows(df, score_a:score_b), df[c(1, 4), ])
  expect_identical(drop_empty_rows(df, score_a, score_b), df[c(1, 4), ])
  expect_identical(drop_empty_rows(df, -c(id, text)), df[c(1, 4), ])
  selected <- c("score_a", "score_b")
  expect_identical(drop_empty_rows(df, all_of(selected)), df[c(1, 4), ])
  wrapper <- function(data, cols) drop_empty_rows(data, {{ cols }})
  expect_identical(wrapper(df, starts_with("score_")), df[c(1, 4), ])
})

test_that("where predicates select the columns to inspect", {
  df <- tibble::tibble(id = c("a", "b", "c"), n = c(NA, 0, 2),
                       m = rep(NA_real_, 3), date = as.Date(c(NA, NA, "2025-01-01")))
  expect_identical(drop_empty_rows(df, where(is.numeric)), df[2:3, ])
  expect_identical(drop_empty_cols(df, where(is.numeric)), df[c("id", "n", "date")])
  expect_identical(drop_empty_rows(df, where(is.character)), df)
})

test_that("column removal only affects selected columns", {
  df <- tibble::tibble(id = 1:2, a = c(NA, NA), b = c(NA, NA), c = c(NA, 1))
  expect_identical(drop_empty_cols(df, a), df[c("id", "b", "c")])
  expect_identical(drop_empty_cols(df, a:c), df[c("id", "c")])
  expect_identical(drop_empty_cols(df), df[c("id", "c")])
  expect_identical(drop_empty_cols(df, c), df)
})

test_that("blank handling is opt-in and never modifies retained cells", {
  df <- tibble::tibble(id = 1:8,
    text = c(NA, "", "  ", "\t\r\n", "\u00a0", "\u2003", " kept ", "0"))
  expect_identical(drop_empty_rows(df, text), df[-1, ])
  expect_identical(drop_empty_rows(df, text, blank = TRUE), df[7:8, ])
  expect_identical(drop_empty_cols(df[1:6, ], text), df[1:6, ])
  expect_identical(drop_empty_cols(df[1:6, ], text, blank = TRUE), df[1:6, "id", drop = FALSE])
  fact <- tibble::tibble(text = factor(c("", " ", " kept "), levels = c("", " ", " kept ", "unused")))
  expect_identical(drop_empty_rows(fact, blank = TRUE), fact[3, , drop = FALSE])
  expect_identical(df$text[7], " kept ")
})

test_that("zero, FALSE, dates, and list contents have explicit semantics", {
  df <- tibble::tibble(n = c(NA, 0, NaN), flag = c(NA, FALSE, NA),
                      date = as.Date(c(NA, NA, "2025-01-01")))
  expect_identical(drop_empty_rows(df, blank = TRUE), df[2:3, ])
  expect_identical(drop_empty_rows(df, n), df[2, ])
  expect_identical(drop_empty_cols(df, blank = TRUE), df)
  lists <- tibble::tibble(x = list(NA, NULL, c(NA, NA), ""))
  expect_identical(drop_empty_rows(lists, blank = TRUE), lists[-1, , drop = FALSE])
})

test_that("empty inputs and selections preserve schema and rows", {
  df <- empty_example()
  for (fun in list(drop_empty_rows, drop_empty_cols)) {
    expect_identical(fun(df, starts_with("absent_")), df)
    expect_identical(fun(df, where(is.factor)), df)
    expect_identical(fun(df, all_of(character())), df)
    expect_identical(fun(df[0, ]), df[0, ])
    expect_identical(fun(df[, 0]), df[, 0])
  }
  all_na <- tibble::tibble(a = c(NA_real_, NA_real_), b = c(NA_character_, NA_character_))
  expect_identical(drop_empty_rows(all_na), all_na[0, ])
  expect_identical(drop_empty_cols(all_na), all_na[, 0])
  expect_identical(drop_empty_cols(drop_empty_rows(all_na)), all_na[0, ])
})

test_that("data-frame classes, row names, and grouping are preserved", {
  df <- data.frame(g = c("a", "a", "b"), x = c(NA, 1, NA), dead = NA_real_,
                   row.names = c("r1", "r2", "r3"))
  expect_identical(drop_empty_rows(df, x), df[2, , drop = FALSE])
  expect_identical(drop_empty_cols(df), df[c("g", "x")])
  grouped <- dplyr::group_by(tibble::as_tibble(df), g)
  expect_identical(drop_empty_rows(grouped, x), grouped[2, , drop = FALSE])
  expect_identical(drop_empty_cols(grouped), grouped[c("g", "x")])
  empty_group <- dplyr::group_by(tibble::tibble(g = c(NA, NA), x = 1:2), g)
  expect_identical(drop_empty_cols(empty_group, g), tibble::tibble(x = 1:2))
  dt <- data.table::as.data.table(df)
  original <- data.table::copy(dt)
  expect_equal(drop_empty_rows(dt, x), dt[2])
  expect_equal(drop_empty_cols(dt), dt[, c("g", "x"), with = FALSE])
  expect_identical(dt, original)
})

test_that("bad arguments and unsupported selected columns give useful errors", {
  for (fun in list(drop_empty_rows, drop_empty_cols)) {
    expect_error(fun(1:3), "data frame")
    expect_error(fun(empty_example(), blank = NA), "TRUE or FALSE")
    expect_error(fun(empty_example(), blank = c(TRUE, FALSE)), "TRUE or FALSE")
    expect_error(fun(empty_example(), blank = "yes"), "TRUE or FALSE")
    expect_error(fun(empty_example(), does_not_exist), "does_not_exist")
    expect_error(fun(empty_example(), renamed = score_a), "rename")
    bad <- data.frame(x = 1, y = 2); names(bad) <- c("x", "x")
    expect_error(fun(bad), "unique")
    nested <- tibble::tibble(id = 1:2, matrix = matrix(NA, 2, 2))
    expect_error(fun(nested, matrix), "one-dimensional")
    expect_identical(fun(nested, id), nested)
  }
})
