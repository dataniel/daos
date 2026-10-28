#' Compare column types across data frames
#'
#' Shows the column types of one or more data frames side-by-side, and
#' classifies each column by whether the datasets could be row-bound as they
#' are. Useful for diagnosing type mismatches before a join or before
#' binding with [lazer::read_files()].
#'
#' @details
#' A type string alone does not say whether two data frames can be stacked:
#' `int` and `dbl` bind without trouble, and so does a column that is
#' entirely `NA` (readr reads an empty column as `lgl`). A column that is
#' absent from one dataset is no obstacle either, since [dplyr::bind_rows()]
#' fills it with `NA`. Only a real conflict such as `chr` vs `dbl` makes the
#' bind fail, or forces [lazer::read_files()] to fall back to character. The
#' `status` column therefore asks the question the function is called for:
#' does it bind?
#'
#' * `"ok"`: present everywhere with the same type.
#' * `"coercible"`: present everywhere, types differ but bind without loss
#'   of structure (`int` + `dbl`, `fct` + `chr`, `date` + `dttm`, an all-`NA`
#'   `lgl` with anything).
#' * `"missing"`: absent from at least one dataset, no conflict among the
#'   rest. Typically a rename or a dropped column upstream.
#' * `"conflict"`: the types cannot be combined.
#'
#' Compatibility is tested by binding zero-row slices of each column with
#' [dplyr::bind_rows()], so the classification follows the same rules as
#' `read_files(out = "bind")`.
#'
#' @param ... Data frames to compare (unquoted), or a single named list of
#'   data frames, such as the default output of [lazer::read_files()]. A list
#'   can also be spliced with `!!!`. Names are inferred from the expressions
#'   passed, or taken from the list.
#' @param diff Logical. If `TRUE`, only columns with status `"conflict"` are
#'   shown, so frames that bind produce an empty result. To see every
#'   difference, filter on `status != "ok"` instead. Default: `FALSE`.
#' @param focus A named character vector of expected types, e.g.
#'   `c(cvr = "chr", year = "int")`. When supplied, only the named columns
#'   are shown, and only for datasets where the type does **not** match (an
#'   absent column counts as a mismatch). Returns an empty tibble (0 rows)
#'   when all types match, so it can be used in checkpoints. Takes
#'   precedence over `diff`.
#'
#' @return A tibble with a `column` column, a `status` column (see Details)
#'   and one column per input dataset showing an abbreviated type string
#'   (`"int"`, `"dbl"`, `"chr"`, `"fct"`, `"date"`, `"dttm"`, ...). `NA`
#'   means the column is absent from that dataset.
#'
#' @examples
#' df1 <- data.frame(x = 1L,  y = "a", z = NA)
#' df2 <- data.frame(x = 1.0, y = 2,   z = "b")
#'
#' view_types(df1, df2)
#' view_types(df1, df2, diff = TRUE)
#' view_types(df1, df2, focus = c(x = "int", y = "chr"))
#'
#' # A named list of data frames, e.g. from read_files():
#' view_types(list(a = df1, b = df2))
#'
#' @seealso [lazer::read_files()], and [expectr::expect_empty()] to use
#'   `view_types(diff = TRUE)` or `focus` as a checkpoint
#'
#' @importFrom rlang list2 enexprs names2 as_label
#' @importFrom dplyr bind_rows
#' @importFrom tibble tibble
#' @importFrom cli cli_abort
#' @export
view_types <- function(..., diff = FALSE, focus = NULL) {
  datasets <- .collect_datasets(...)

  types <- lapply(datasets, \(d) vapply(d, .type_sum, character(1)))
  cols  <- unique(unlist(lapply(types, names), use.names = FALSE))

  out <- tibble::tibble(
    column = cols,
    status = vapply(cols, \(col) .type_status(datasets, col), character(1),
                    USE.NAMES = FALSE)
  )
  for (nm in names(datasets)) out[[nm]] <- unname(types[[nm]][cols])

  if (!is.null(focus)) {
    if (!is.character(focus) || length(focus) == 0 || !rlang::is_named(focus) ||
        anyDuplicated(names(focus))) {
      cli::cli_abort(c(
        "`focus` must be a named character vector with unique names.",
        "i" = "For example {.code c(cvr = \"chr\", year = \"int\")}."
      ))
    }
    unknown <- setdiff(names(focus), out$column)
    if (length(unknown)) {
      cli::cli_abort("Column{?s} {.var {unknown}} {?was/were} not found.")
    }

    out <- out[match(names(focus), out$column), ]
    bad <- matrix(
      vapply(names(datasets), \(nm) is.na(out[[nm]]) | out[[nm]] != unname(focus),
             logical(nrow(out))),
      nrow = nrow(out)
    )
    out[rowSums(bad) > 0, c("column", "status", names(datasets)[colSums(bad) > 0])]

  } else if (diff) {
    out[out$status == "conflict", ]

  } else {
    out
  }
}

# Turns the dots into a named list of data frames. A single list of data
# frames is unpacked, so the output of read_files() can be passed directly.
# Dataset names are made unique and kept clear of "column" and "status".
.collect_datasets <- function(...) {
  datasets <- rlang::list2(...)
  if (length(datasets) == 0) cli::cli_abort("Please supply at least one dataset.")

  if (length(datasets) == 1 && is.list(datasets[[1]]) && !is.data.frame(datasets[[1]])) {
    datasets <- datasets[[1]]
    if (length(datasets) == 0) cli::cli_abort("The supplied list is empty.")
    nms <- rlang::names2(datasets)
    nms[nms == ""] <- as.character(which(nms == ""))
  } else {
    # Spliced data frames (`!!!lst`) arrive as values, not expressions; label
    # those by position instead of deparsing a whole data frame.
    exprs <- rlang::enexprs(...)
    nms   <- rlang::names2(datasets)
    for (i in which(nms == "")) {
      e <- exprs[[i]]
      nms[i] <- if (is.symbol(e) || is.call(e)) rlang::as_label(e) else as.character(i)
    }
  }

  is_df <- vapply(datasets, is.data.frame, logical(1))
  if (!all(is_df)) {
    bad <- unique(vapply(datasets[!is_df], \(x) class(x)[1], character(1)))
    cli::cli_abort(c(
      "All inputs must be data frames or tibbles.",
      "x" = "Invalid input type{?s}: {bad}.",
      "i" = "Pass a list of data frames on its own, or splice it with {.code !!!}."
    ))
  }

  names(datasets) <- make.unique(c("column", "status", nms))[-(1:2)]
  datasets
}

# Classifies one column across datasets: "conflict" if the present columns
# cannot be bound, else "missing" if absent somewhere, else "coercible" if
# the types differ, else "ok".
.type_status <- function(datasets, col) {
  present <- lapply(Filter(\(d) col %in% names(d), datasets), `[[`, col)
  differs <- length(unique(vapply(present, .type_sum, character(1)))) > 1

  if (differs && !.binds(present)) return("conflict")
  if (length(present) < length(datasets)) return("missing")
  if (differs) return("coercible")
  "ok"
}

# TRUE if the columns can be row-bound. All-NA logical columns are left out,
# since they combine with any type (readr reads an empty column as lgl).
.binds <- function(xs) {
  xs <- Filter(\(x) !(is.logical(x) && all(is.na(x))), xs)
  tryCatch({
    dplyr::bind_rows(lapply(xs, \(x) tibble::tibble(v = x[0])))
    TRUE
  }, error = \(e) FALSE)
}

# Abbreviated type string for a column, mirroring pillar::type_sum() for the
# common cases ("int", "dbl", "chr", "fct", "date", "dttm", ...). Unknown
# classed objects fall back to their first class name.
.type_sum <- function(x) {
  if (is.object(x)) {
    if (is.factor(x))           return("fct")
    if (inherits(x, "Date"))    return("date")
    if (inherits(x, "POSIXct")) return("dttm")
    if (inherits(x, "difftime")) return("drtn")
    return(class(x)[1])
  }
  switch(typeof(x),
         logical   = "lgl",
         integer   = "int",
         double    = "dbl",
         character = "chr",
         complex   = "cpl",
         list      = "list",
         typeof(x))
}
