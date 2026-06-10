#' Compare column types across data frames
#'
#' Shows the column types of one or more data frames side-by-side. Useful
#' for diagnosing type mismatches before a join or before binding with [daos::read_files()].
#'
#' @param ... Data frames to compare (unquoted). Names are inferred from the
#'   expressions passed.
#' @param diff Logical. If `TRUE`, only columns where types differ across
#'   datasets are shown. Default: `FALSE`.
#' @param focus A named length-1 character vector, e.g. `c(year = "int")`.
#'   When supplied, only the named column is shown, and only for datasets
#'   where the type does **not** match the expected type. Returns an empty
#'   tibble (0 rows) when all types match — suitable for use in tests.
#'
#' @return A tibble with a `column` column and one column per input dataset
#'   showing an abbreviated type string (`"int"`, `"dbl"`, `"chr"`, `"fct"`,
#'   `"date"`, `"dttm"`, ...).
#'
#' @examples
#' df1 <- data.frame(x = 1L, y = "a")
#' df2 <- data.frame(x = 1.0, y = "b")
#'
#' view_types(df1, df2)
#' view_types(df1, df2, diff = TRUE)
#' view_types(df1, df2, focus = c(x = "int"))
#'
#' @seealso [daos::read_files()]
#'
#' @importFrom rlang list2 enexprs .data
#' @importFrom dplyr full_join filter n_distinct
#' @importFrom tibble tibble
#' @importFrom cli cli_abort
#' @export
view_types <- function(..., diff = FALSE, focus = NULL) {
  datasets <- rlang::list2(...)
  names(datasets) <- names(rlang::enexprs(..., .named = TRUE))

  if (length(datasets) == 0) cli::cli_abort("Please supply at least one dataset.")

  is_df <- vapply(datasets, is.data.frame, logical(1))
  bad <- unique(vapply(datasets, \(x) class(x)[1], character(1))[!is_df])
  if (length(bad)) {
    cli::cli_abort(c("All inputs must be data frames or tibbles.",
                     "x" = "Invalid input type{?s}: {bad}."))
  }

  out <- Map(
    \(data, nm) tibble::tibble(column = names(data),
                               !!nm := vapply(data, .type_sum, character(1))),
    datasets, names(datasets)
  ) |>
    Reduce(f = \(x, y) dplyr::full_join(x, y, by = "column"))

  if (!is.null(focus)) {
    if (!is.character(focus) || length(focus) != 1 || !rlang::is_named(focus)) {
      cli::cli_abort("`focus` must be a named string, e.g. `c(Species = \"fct\")`.")
    }
    out <- dplyr::filter(out, .data[["column"]] == names(focus))
    if (nrow(out) == 0) cli::cli_abort("Column {.var {names(focus)}} was not found.")

    keep <- vapply(out[-1], \(x) is.na(x) || x != unname(focus), logical(1))
    out  <- out[, c(TRUE, keep)]
    if (ncol(out) == 1) out[0, ] else out

  } else if (diff) {
    out[apply(out[-1], 1, \(x) dplyr::n_distinct(x, na.rm = FALSE) > 1), ]

  } else {
    out
  }
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
