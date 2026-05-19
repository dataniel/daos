#' Compare column types across data frames
#'
#' Shows the column types of one or more data frames side-by-side. Useful
#' for diagnosing type mismatches before a join or a call to [daos::bind_files()].
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
#'   showing the [`pillar::type_sum()`] type string.
#'
#' @examples
#' df1 <- data.frame(x = 1L, y = "a")
#' df2 <- data.frame(x = 1.0, y = "b")
#'
#' view_types(df1, df2)
#' view_types(df1, df2, diff = TRUE)
#' view_types(df1, df2, focus = c(x = "int"))
#'
#' @seealso [daos::bind_files()]
#'
#' @importFrom rlang list2 enexprs .data
#' @importFrom purrr map_chr map_lgl imap reduce
#' @importFrom dplyr full_join filter n_distinct
#' @importFrom tibble tibble
#' @importFrom pillar type_sum
#' @importFrom cli cli_abort
#' @export
view_types <- function(..., diff = FALSE, focus = NULL) {
  datasets <- rlang::list2(...)
  names(datasets) <- names(rlang::enexprs(..., .named = TRUE))

  if (length(datasets) == 0) cli::cli_abort("Please supply at least one dataset.")

  bad <- unique(purrr::map_chr(datasets, \(x) class(x)[1])[!purrr::map_lgl(datasets, is.data.frame)])
  if (length(bad)) {
    cli::cli_abort(c("All inputs must be data frames or tibbles.",
                     "x" = "Invalid input type{?s}: {bad}."))
  }

  out <- purrr::imap(datasets, \(data, nm) {
    tibble::tibble(column = names(data),
                   !!nm := purrr::map_chr(data, pillar::type_sum))
  }) |>
    purrr::reduce(dplyr::full_join, by = "column")

  if (!is.null(focus)) {
    if (!is.character(focus) || length(focus) != 1 || !rlang::is_named(focus)) {
      cli::cli_abort("`focus` must be a named string, e.g. `c(Species = \"fct\")`.")
    }
    out <- dplyr::filter(out, .data[["column"]] == names(focus))
    if (nrow(out) == 0) cli::cli_abort("Column {.var {names(focus)}} was not found.")

    keep <- purrr::map_lgl(out[-1], \(x) is.na(x) || x != unname(focus))
    out  <- out[, c(TRUE, keep)]
    if (ncol(out) == 1) out[0, ] else out

  } else if (diff) {
    out[apply(out[-1], 1, \(x) dplyr::n_distinct(x, na.rm = FALSE) > 1), ]

  } else {
    out
  }
}
