#' Unpack a named list into individual variables
#'
#' Assigns each element of a named list to its own variable in a target
#' environment. This is the complement of [daos::read_files()] when you want
#' individual named objects rather than a single list.
#'
#' @param data A fully named list.
#' @param .envir Target environment. Default is the calling environment.
#' @param .overwrite If `FALSE` (default), aborts when any name already
#'   exists in the target environment. Set to `TRUE` to allow overwrites.
#'
#' @return `data` invisibly.
#'
#' @examples
#' \dontrun{
#' # Read files into separate variables:
#' require_files("data/dat{0:9}.parquet") |>
#'   read_files() |>
#'   unpack_files()
#'
#' # dat0, dat1, ..., dat9 now exist in the environment.
#' # Collect them again:
#' summon("^dat\\d+$")
#' }
#'
#' @seealso [daos::read_files()], [daos::summon()]
#'
#' @importFrom cli cli_abort
#' @export
unpack_files <- function(data, .envir = parent.frame(), .overwrite = FALSE) {

  if (!is.list(data)) {
    cli::cli_abort("{.arg data} must be a list.")
  }

  if (is.null(names(data)) || any(names(data) == "")) {
    cli::cli_abort("{.arg data} must be fully named.")
  }

  if (!.overwrite) {
    existing <- intersect(names(data), ls(envir = .envir))
    if (length(existing) > 0) {
      cli::cli_abort(c(
        "{length(existing)} object{?s} already exist{?s/} in target environment.",
        "x" = "Conflicts: {.val {existing}}.",
        "i" = "Set {.code .overwrite = TRUE} to replace them."
      ))
    }
  }

  list2env(data, envir = .envir)
  invisible(data)
}
