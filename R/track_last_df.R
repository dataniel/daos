#' Track the last data frame printed in the console
#'
#' Installs a task callback that automatically saves any data frame returned
#' to the console as a named variable in the global environment. Intermediate
#' expressions (`1 + 1`, plots, etc.) are ignored — only top-level data frame
#' returns are captured.
#'
#' Calling `track_last_df()` again replaces any existing callback, preventing
#' duplicates.
#'
#' @param on `TRUE` to enable tracking (default), `FALSE` to disable.
#' @param name Name of the variable written in `.GlobalEnv`. Default:
#'   `".last.df"`.
#'
#' @return `TRUE` invisibly.
#'
#' @examples
#' \dontrun{
#' track_last_df()          # enable
#' dplyr::starwars |> head()
#' .last.df                 # the last printed data frame
#'
#' track_last_df(FALSE)     # disable
#' }
#'
#' @importFrom cli cli_alert_success cli_alert_info
#' @export
track_last_df <- function(on = TRUE, name = ".last.df") {

  callback_name <- "track_last_df"

  existing <- getTaskCallbackNames()
  if (callback_name %in% existing) {
    removeTaskCallback(callback_name)
  }

  if (!isTRUE(on)) {
    cli::cli_alert_info("Tracking of {.var {name}} disabled.")
    return(invisible(TRUE))
  }

  addTaskCallback(
    function(expr, value, ok, visible) {
      if (ok && is.data.frame(value)) {
        assign(name, value, envir = globalenv())
      }
      TRUE
    },
    name = callback_name
  )

  cli::cli_alert_success("Tracking of {.var {name}} enabled.")
  invisible(TRUE)
}
