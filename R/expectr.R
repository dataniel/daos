#' Checkpoints, now in the expectr package
#'
#' The validation checkpoints and their helpers moved from daos to the
#' expectr package: [expectr::expect_empty()], [expectr::expect_none()],
#' [expectr::expect_unique()], [expectr::expect_balanced()],
#' [expectr::expect_no_overlap()] and [expectr::tally_violations()]. They
#' share an engine and a contract the rest of daos does not, so they are
#' developed there. See `vignette("expectr", package = "expectr")`. The
#' inspection helpers [flag_duplicates()] and [view_types()] stay in daos.
#'
#' daos keeps a function of the same name for each, so existing scripts
#' keep working. It calls expectr, says once per session that the function
#' has moved, and keeps the old names working:
#'
#' * `options(daos.check_log = , daos.check_dump = )` are used when the new
#'   `expectr.log` and `expectr.dump` are not set.
#' * A failed check also carries the old condition class
#'   `daos_check_failure`, so `tryCatch(daos_check_failure = )` still
#'   catches it.
#'
#' New code should call expectr directly, e.g. with `library(expectr)`.
#'
#' @param ... Passed on to the expectr function of the same name.
#'
#' @return What the expectr function returns.
#'
#' @name moved-to-expectr
#' @keywords internal
NULL

#' @rdname moved-to-expectr
#' @export
expect_empty <- function(...) call_expectr("expect_empty", ...)

#' @rdname moved-to-expectr
#' @export
expect_none <- function(...) call_expectr("expect_none", ...)

#' @rdname moved-to-expectr
#' @export
expect_unique <- function(...) call_expectr("expect_unique", ...)

#' @rdname moved-to-expectr
#' @export
expect_balanced <- function(...) call_expectr("expect_balanced", ...)

#' @rdname moved-to-expectr
#' @export
expect_no_overlap <- function(...) call_expectr("expect_no_overlap", ...)

#' @rdname moved-to-expectr
#' @export
tally_violations <- function(...) call_expectr("tally_violations", ...)

# Calls the expectr function `fun`, with the old daos option names as a
# fallback and the old condition class added to a failure. The arguments
# travel as `...`, which keeps tidy evaluation intact: `{{ id }}` and
# conditions in expectr see the caller's expressions.
call_expectr <- function(fun, ...) {
  rlang::inform(
    c(paste0("The checkpoints have moved to the expectr package; daos forwards `",
             fun, "()` to `expectr::", fun, "()`."),
      "i" = "Use `library(expectr)` in new code. This message is shown once per session."),
    .frequency = "once", .frequency_id = "daos_moved_to_expectr",
    class = "daos_moved_to_expectr"
  )

  old <- options(
    expectr.log  = getOption("expectr.log",  getOption("daos.check_log")),
    expectr.dump = getOption("expectr.dump", getOption("daos.check_dump"))
  )
  on.exit(options(old), add = TRUE)

  target <- switch(fun,
    expect_empty      = expectr::expect_empty,
    expect_none       = expectr::expect_none,
    expect_unique     = expectr::expect_unique,
    expect_balanced   = expectr::expect_balanced,
    expect_no_overlap = expectr::expect_no_overlap,
    tally_violations  = expectr::tally_violations
  )

  # Called by its own name, so an error reads "Error in `expect_none()`"
  env <- new.env(parent = environment())
  assign(fun, target, envir = env)

  withCallingHandlers(
    eval(call(fun, quote(...)), env),
    expectr_failure = function(cnd) {
      if (inherits(cnd, "daos_check_failure")) return()
      class(cnd) <- c("daos_check_failure", class(cnd))
      if (inherits(cnd, "error")) stop(cnd)
      warning(cnd)
      invokeRestart("muffleWarning")
    }
  )
}
