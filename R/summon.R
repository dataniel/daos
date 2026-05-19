#' Retrieve objects matching a pattern from an environment
#'
#' Searches an environment for objects whose names match a regular expression
#' and returns them as a named list. Useful for collecting a family of
#' similarly-named objects (e.g. `dat0` through `dat9`) after unpacking a
#' list with [daos::unpack_files()].
#'
#' @param pattern A single regular expression string.
#' @param .envir The environment to search. Default is the calling
#'   environment.
#'
#' @return A named list of matching objects.
#'
#' @examples
#' dat1 <- data.frame(x = 1)
#' dat2 <- data.frame(x = 2)
#' dat3 <- data.frame(x = 3)
#' summon("^dat\\d+$")
#'
#' @seealso [daos::read_files()], [daos::split_by()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang set_names
#' @export
summon <- function(pattern, .envir = parent.frame()) {

  if (!is.character(pattern) || length(pattern) != 1) {
    cli::cli_abort("{.arg pattern} must be a single string.")
  }

  nms <- ls(envir = .envir, pattern = pattern)

  if (length(nms) == 0) {
    cli::cli_abort(c(
      "No objects matching {.val {pattern}} found.",
      "i" = "Searched in {.envir {environmentName(.envir)}}."
    ))
  }

  rlang::set_names(mget(nms, envir = .envir), nms)
}
