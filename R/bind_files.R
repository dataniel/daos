#' Row-bind a list of data frames
#'
#' Combines a list of data frames into a single tibble using
#' [`purrr::list_rbind()`]. When column types differ across files,
#' an informative error is raised with hints for resolution.
#' Setting `.guess = TRUE` converts all columns to character first, then
#' lets [`readr::type_convert()`] infer a common type.
#'
#' @param data A list of data frames or tibbles.
#' @param .id Name of the source column added to identify which data frame
#'   each row originated from. Default is `"source"`.
#' @param .guess If `TRUE`, all columns are coerced to character before
#'   binding and then re-typed automatically. Use when column types differ
#'   across files. Default is `FALSE`.
#'
#' @return A single tibble with all rows combined and a `source` column
#'   (or whatever `.id` names it).
#'
#' @examples
#' df1 <- data.frame(x = 1:3, y = letters[1:3])
#' df2 <- data.frame(x = 4:5, y = letters[4:5])
#' bind_files(list(a = df1, b = df2))
#'
#' # Force type guessing when types differ:
#' df3 <- data.frame(x = c("1", "2"))
#' df4 <- data.frame(x = c(3L, 4L))
#' bind_files(list(df3, df4), .guess = TRUE)
#'
#' @seealso [daos::view_types()] to inspect type differences before binding
#'
#' @importFrom purrr map_lgl list_rbind map
#' @importFrom dplyr mutate across everything
#' @importFrom readr type_convert
#' @importFrom cli cli_abort
#' @export
bind_files <- function(data, .id = "source", .guess = FALSE) {

  if (!is.list(data) || !all(purrr::map_lgl(data, is.data.frame))) {
    cli::cli_abort("{.arg data} must be a list of data frames.")
  }

  result <- tryCatch(purrr::list_rbind(data, names_to = .id), error = function(e) e)
  if (!inherits(result, "error")) return(result)

  if (!.guess) {
    cli::cli_abort(c(
      "Datasets cannot be combined.",
      "x" = "Column types differ across files.",
      "i" = "Set {.code .guess = TRUE} to auto-detect a common type spec.",
      "i" = "Use {.code view_types(!!!data, diff = TRUE)} to inspect the differences."
    ))
  }

  data |>
    purrr::map(\(d) dplyr::mutate(d, dplyr::across(dplyr::everything(), as.character))) |>
    purrr::list_rbind(names_to = .id) |>
    readr::type_convert()
}
