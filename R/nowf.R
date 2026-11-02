#' Formatted timestamp for now
#'
#' A shorthand for `format(Sys.time(), fmt)`, with names for the formats
#' that come up again and again. Useful for constructing file names and log
#' paths with a timestamp baked in.
#'
#' @param fmt A named format, or a format string as accepted by
#'   [`strftime()`][base::strftime]. Default `"date"`.
#'
#' | Name | Format | Example |
#' | --- | --- | --- |
#' | `"date"` | `%Y%m%d` | `20261102` |
#' | `"datetime"` | `%Y%m%d_%H%M%S` | `20261102_143022` |
#' | `"iso"` | `%Y-%m-%d` | `2026-11-02` |
#' | `"month"` | `%Y%m` | `202611` |
#' | `"year"` | `%Y` | `2026` |
#' | `"time"` | `%H%M%S` | `143022` |
#' | `"stamp"` | `%Y-%m-%d %H:%M:%S` | `2026-11-02 14:30:22` |
#'
#' @details
#' The names are words rather than numbers, so `nowf("datetime")` says what
#' it gives to whoever reads the code next. The file-name formats sort
#' chronologically and contain no characters Windows forbids; `"stamp"` is
#' for logs and has colons, so not for file names.
#'
#' A string without `%` that is not one of the names is an error, so a
#' typo such as `"datetiem"` does not silently become a file name.
#'
#' @return A single character string with the formatted timestamp.
#'
#' @examples
#' nowf()                 # e.g. "20261102"
#' nowf("datetime")       # e.g. "20261102_143022"
#' nowf("iso")            # e.g. "2026-11-02"
#' nowf("%Y%B")           # any strftime format, e.g. "2026November"
#'
#' # Typical use in file paths:
#' \dontrun{
#' f("log/{nowf()}/0-check_data.log")
#' f("data/export_{nowf('datetime')}.parquet")
#' }
#'
#' @seealso [daos::f()] for string interpolation
#'
#' @export
nowf <- function(fmt = "date") {
  if (!is.character(fmt) || length(fmt) != 1L || is.na(fmt)) {
    cli::cli_abort("{.arg fmt} must be a single format name or strftime string.")
  }
  if (fmt %in% names(.nowf_formats)) {
    fmt <- .nowf_formats[[fmt]]
  } else if (!grepl("%", fmt, fixed = TRUE)) {
    cli::cli_abort(c("Unknown format name {.val {fmt}}.",
      "i" = "Use one of {.val {names(.nowf_formats)}}, or a strftime string such as {.val %Y-%m}."))
  }
  format(Sys.time(), fmt)
}

.nowf_formats <- c(
  date = "%Y%m%d",
  datetime = "%Y%m%d_%H%M%S",
  iso = "%Y-%m-%d",
  month = "%Y%m",
  year = "%Y",
  time = "%H%M%S",
  stamp = "%Y-%m-%d %H:%M:%S"
)
