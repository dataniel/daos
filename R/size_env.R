#' Show object sizes in an environment
#'
#' Lists all objects in an environment sorted by size (descending), with
#' both raw byte counts and human-readable representations.
#'
#' @param .envir The environment to inspect. Default is the calling
#'   environment.
#' @param n Optional integer. If supplied, only the `n` largest objects are
#'   returned.
#'
#' @return A tibble with columns `name` (character), `size` (numeric, bytes),
#'   and `pretty` (fs_bytes, human-readable). Returns `NULL` invisibly if the
#'   environment is empty.
#'
#' @examples
#' x <- 1:1e6
#' y <- letters
#' size_env()       # all objects
#' size_env(n = 1)  # only the largest
#'
#' @importFrom purrr map_dbl
#' @importFrom tibble tibble
#' @importFrom dplyr arrange desc
#' @importFrom fs as_fs_bytes
#' @importFrom cli cli_alert_info
#' @importFrom utils object.size head
#' @export
size_env <- function(.envir = parent.frame(), n = NULL) {

  objs <- ls(envir = .envir)

  if (length(objs) == 0) {
    cli::cli_alert_info("Environment is empty.")
    return(invisible(NULL))
  }

  sizes <- purrr::map_dbl(
    objs,
    \(x) as.numeric(utils::object.size(get(x, envir = .envir)))
  )

  out <- tibble::tibble(name = objs, size = sizes,
                        pretty = fs::as_fs_bytes(sizes)) |>
    dplyr::arrange(dplyr::desc(.data$size))

  if (is.null(n)) out else utils::head(out, n)
}
