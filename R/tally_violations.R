#' Count violations for several rules at once
#'
#' Evaluates a set of named rules and returns one row per rule with the
#' number of violating rows. Where a chain of [expect_none()] calls stops at
#' the first abort, `tally_violations()` evaluates every rule, so a delivery
#' with five problems is reported as five problems in one go.
#'
#' ## Why "tally"
#'
#' To tally is to keep count, as with tally marks or [dplyr::tally()]. The
#' name marks the difference from the `expect_*()` family: those *judge* (a
#' check passes, warns or aborts), while `tally_violations()` only *counts*
#' and never warns or stops. Severity stays a separate, explicit decision,
#' made afterwards by piping the tally into [expect_empty()]. The same tally
#' therefore serves both as a hard gate in production and as a report you
#' read or send on.
#'
#' The result is itself a violation set once filtered, which closes the loop
#' back to [expect_empty()]:
#'
#' ```r
#' df |>
#'   tally_violations(
#'     "Missing id"       = is.na(id),
#'     "Negative amount"  = amount < 0,
#'     "Unknown industry" = !branche %in% codebook$branche
#'   ) |>
#'   dplyr::filter(n > 0) |>
#'   expect_empty(abort_msg = "The delivery failed validation")
#' ```
#'
#' Kept unfiltered, it is a validation report: send it back to whoever made
#' the data, e.g. with [write_excel()] after dropping the `rows` column.
#'
#' Rules follow [dplyr::filter()] semantics: each must give `TRUE` for a
#' violating row, and `NA` counts as no violation. Rules are evaluated with
#' [dplyr::mutate()], so `if_any()`, `across()` and grouped data work.
#'
#' @param data A data frame or tibble.
#' @param ... Rules that describe a violating row. Name them; an unnamed rule
#'   is named after its expression.
#'
#' @return A tibble with one row per rule and the columns `rule` (name),
#'   `n` (number of violating rows) and `rows` (list of their row numbers in
#'   `data`, for `data[rows[[i]], ]`).
#'
#' @examples
#' tally_violations(ggplot2::mpg,
#'   "Few cylinders"  = cyl < 4,
#'   "High mileage"   = hwy > 40,
#'   "Missing model"  = is.na(model)
#' )
#'
#' @seealso [expect_empty()], [expect_none()]
#'
#' @export
tally_violations <- function(data, ...) {
  check_data_frame(data)
  rules <- rlang::enquos(..., .named = TRUE)
  if (length(rules) == 0) {
    cli::cli_abort("Supply at least one rule in {.arg ...}.")
  }

  call <- rlang::current_env()
  rows <- lapply(names(rules), function(name) {
    hit <- tryCatch(
      dplyr::mutate(data, .daos_rule = !!rules[[name]], .keep = "none")$.daos_rule,
      error = function(e) {
        cli::cli_abort("Rule {.val {name}} could not be evaluated.",
                       parent = e, call = call)
      }
    )
    if (!is.logical(hit)) {
      cli::cli_abort(
        "Rule {.val {name}} must give a logical vector, not {.cls {class(hit)}}.",
        call = call
      )
    }
    which(hit)
  })

  tibble::tibble(
    rule = names(rules),
    n    = lengths(rows),
    rows = rows
  )
}
