#' Assert that a data frame is empty
#'
#' A pipeline-friendly validation checkpoint. Emits a success alert when the
#' data frame has zero rows, otherwise warns or aborts. Optionally appends a
#' timestamped entry to a log file — useful for automated pipelines where you
#' want a minimal audit trail without noise.
#'
#' @param data A data frame or tibble.
#' @param success_msg Message shown (and logged) when `data` is empty.
#'   Default: `"The dataset is empty."`.
#' @param warn_msg Message shown (and logged) when `data` is not empty and no
#'   `abort_msg` is set. Default: `"The dataset is not empty."`.
#' @param abort_msg If provided, `cli::cli_abort()` is called with this
#'   message when `data` is not empty. If `NULL` (default), a warning is
#'   issued instead.
#' @param log Optional path to a log file. The directory is created
#'   automatically if it does not exist. Each entry is prefixed with a
#'   timestamp and a symbol (`✔`, `✖`, or `!`).
#'
#' @return `data` invisibly.
#'
#' @examples
#' # Success — no rows
#' data.frame() |> expect_empty()
#'
#' # Warning — unexpected rows
#' dplyr::filter(ggplot2::mpg, cyl < 0) |>
#'   expect_empty(warn_msg = "Negative cylinder counts found")
#'
#' # Abort — treat unexpected rows as a hard error
#' \dontrun{
#' dplyr::filter(dplyr::starwars, height < 0) |>
#'   expect_empty(abort_msg = "Impossible: negative height")
#' }
#'
#' # With logging:
#' \dontrun{
#' log_path <- f("log/{nowf()}/checks.log")
#' checker  <- \(data, ...) expect_empty(data, ..., log = log_path)
#'
#' dplyr::filter(dplyr::starwars, name == "Harry Potter") |>
#'   checker(success_msg = "No Harry Potter rows")
#' }
#'
#' @seealso [daos::flag_duplicates()]
#'
#' @importFrom cli cli_abort cli_warn cli_alert_success
#' @export
expect_empty <- function(data,
                         success_msg = "The dataset is empty.",
                         warn_msg    = "The dataset is not empty.",
                         abort_msg   = NULL,
                         log         = NULL) {

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.")
  }

  write_log <- function(symbol, msg) {
    if (is.null(log)) return(invisible())
    dir.create(dirname(log), recursive = TRUE, showWarnings = FALSE)
    cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", symbol, msg, "\n",
        file = log, append = TRUE)
  }

  if (nrow(data) == 0) {
    cli::cli_alert_success(success_msg)
    write_log("\u2714", success_msg)
    return(invisible(data))
  }

  if (!is.null(abort_msg)) {
    write_log("\u2716", abort_msg)
    cli::cli_abort(abort_msg)
  }

  write_log("!", warn_msg)
  cli::cli_warn(warn_msg)
  invisible(data)
}
