#' Formatted timestamp for now
#'
#' A shorthand for `format(lubridate::now(), fmt)`. Useful for constructing
#' file names and log paths with a timestamp baked in.
#'
#' @param fmt Format string as accepted by [`strftime()`][base::strftime].
#'   Default is `"%Y%m%d"` (ISO date without separators).
#'
#' @return A single character string with the formatted timestamp.
#'
#' @examples
#' nowf()                 # e.g. "20260518"
#' nowf("%Y%m%d_%H%M%S")  # e.g. "20260518_143022"
#' nowf("%Y%B")           # e.g. "2026May"
#'
#' # Typical use in file paths:
#' \dontrun{
#' f("log/{nowf()}/0-check_data.log")
#' f("data/export_{nowf('%Y%m%d_%H%M%S')}.parquet")
#' }
#'
#' @seealso [daos::f()] for string interpolation
#'
#' @importFrom lubridate now
#' @export
nowf <- function(fmt = "%Y%m%d") {
  format(lubridate::now(), fmt)
}
