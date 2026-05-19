#' Validate and resolve file paths
#'
#' Expands paths using [`glue::glue()`] (so `{0:9}` generates ten paths),
#' checks that every file exists, and returns a named character vector ready
#' to pipe into [daos::read_files()]. Aborts immediately if any file is missing.
#'
#' @param paths A character vector of file paths. Glue syntax (`{}`) is
#'   supported for compact range expansion.
#' @param .names Optional character vector of names to assign to the returned
#'   paths. Defaults to the file name without extension.
#' @param .envir Environment used for glue interpolation. Default is the
#'   calling frame.
#'
#' @return A named character vector of validated file paths.
#'
#' @examples
#' \dontrun{
#' # Validate ten files at once using glue expansion:
#' require_files("data/dat{0:9}.parquet")
#'
#' # Pipe directly into read_files():
#' require_files("data/dat{0:9}.parquet") |> read_files()
#'
#' # Full pipeline: validate -> read -> bind:
#' require_files("data/dat{0:9}.parquet") |>
#'   read_files() |>
#'   bind_files()
#' }
#'
#' @seealso [daos::read_files()], [daos::bind_files()]
#'
#' @importFrom glue glue
#' @importFrom fs file_exists path_file path_ext_remove
#' @importFrom cli cli_abort
#' @importFrom rlang %||%
#' @importFrom stats setNames
#' @export
require_files <- function(paths, .names = NULL, .envir = parent.frame()) {

  files   <- glue::glue(paths, .envir = .envir)
  missing <- files[!fs::file_exists(files)]

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{length(missing)} of {length(files)} file{?s} could not be found.",
      "",
      "{.strong Missing files:}",
      stats::setNames(fs::path_file(missing), rep("x", length(missing)))
    ))
  }

  .names <- .names %||% (files |> fs::path_file() |> fs::path_ext_remove())

  if (length(.names) != length(files)) {
    cli::cli_abort("{.arg .names} must have the same length as the number of files.")
  }

  stats::setNames(as.character(files), .names)
}
