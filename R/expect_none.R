#' Assert that no rows match a condition
#'
#' The in-pipeline form of [expect_empty()]. Instead of filtering for the
#' violations and piping *them* in, pass the condition directly. The check is
#' the same, but `data` itself is returned, so the pipeline continues with
#' all rows:
#'
#' ```r
#' df |>
#'   expect_none(is.na(id), abort_msg = "Rows without an id") |>
#'   expect_none(amount < 0) |>
#'   mutate(...)
#' ```
#'
#' Conditions follow [dplyr::filter()] semantics: several conditions are
#' combined with `&`, and a row where a condition is `NA` does not count as a
#' violation. Test for missing values explicitly with `is.na()` when they
#' matter.
#'
#' Without a message, the condition itself becomes the message
#' (`"Found rows where amount < 0"`), which is often clear enough during
#' exploration. Write your own message for checks that stay in production.
#'
#' @param ... Conditions that describe a violating row, as in
#'   [dplyr::filter()].
#' @inheritParams expect_empty
#' @param warn_msg Message shown (and logged) when rows match and no
#'   `abort_msg` is set. Defaults to a description of the condition.
#'
#' @return `data` invisibly, unchanged.
#'
#' @examples
#' ggplot2::mpg |>
#'   expect_none(cyl < 4) |>
#'   expect_none(hwy > 40, warn_msg = "Implausibly efficient cars") |>
#'   nrow()
#'
#' \dontrun{
#' dplyr::starwars |>
#'   expect_none(is.na(species), abort_msg = "Characters without a species")
#' }
#'
#' @seealso [expect_empty()], [expect_unique()], [tally_violations()]
#'
#' @export
expect_none <- function(data, ...,
                        success_msg = NULL,
                        warn_msg    = NULL,
                        abort_msg   = NULL,
                        log         = getOption("daos.check_log"),
                        dump        = getOption("daos.check_dump")) {

  tbl <- check_table(data)
  conditions <- rlang::enquos(...)
  if (length(conditions) == 0) {
    cli::cli_abort("Supply at least one condition in {.arg ...}.")
  }

  label <- abort_msg %||% warn_msg
  rule  <- paste(vapply(conditions, rlang::as_label, character(1)), collapse = " & ")

  report_check(
    violations  = dplyr::filter(tbl, !!!conditions),
    success_msg = success_msg %||%
      if (is.null(label)) paste0("No rows where ", rule) else paste0("Check passed: ", label),
    fail_msg    = label %||% paste0("Found rows where ", rule),
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump
  )
  invisible(data)
}
