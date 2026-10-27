#' Assert that a panel is balanced, or has no gaps
#'
#' A checkpoint for register panels: every unit (person, company, workplace)
#' must be observed in every period. Missing unit-periods are the violation
#' set, so a failure lists exactly which units lack which periods. Returns
#' `data`, so it can sit in the middle of a pipeline.
#'
#' Register populations are rarely fully balanced: people are born, die and
#' migrate, and firms open and close. `gaps_only = TRUE` relaxes the rule to
#' what usually *should* hold: a unit may enter late and leave early, but
#' once present it must not skip a period between its first and last. A
#' person present in 2019 and 2021 but missing in 2020 is then a gap; a
#' person first seen in 2021 is not.
#'
#' ## What counts as a period
#'
#' By default the expected periods are those observed anywhere in the data.
#' A period missing for *every* unit (e.g. a year that was never loaded) is
#' therefore invisible. Pass the periods you expect, e.g.
#' `periods = 2015:2024`, to catch that too. Observations outside `periods`
#' are ignored, as are rows with a missing period.
#'
#' Duplicated unit-periods do not make a panel unbalanced, but they are
#' usually an error of their own: check them with
#' [expect_unique()]`(data, id, time)`.
#'
#' The check scales to full-population registers: the unit-period grid is
#' only built for units that actually lack a period.
#'
#' @param data A data frame or tibble.
#' @param id Column(s) identifying the unit (tidy-select), e.g. `cpr` or
#'   `c(cvr, lbnr)`.
#' @param time The period column (one column), e.g. `year`. Any type that
#'   sorts, such as integer years or dates.
#' @param periods Expected periods. Defaults to the periods observed in
#'   `data`.
#' @param gaps_only If `FALSE` (default), every unit must be observed in every
#'   period. If `TRUE`, only periods between a unit's first and last
#'   observation are required.
#' @inheritParams expect_empty
#' @param warn_msg Message shown (and logged) when unit-periods are missing
#'   and no `abort_msg` is set. Defaults to a description of the check.
#'
#' @return `data` invisibly, unchanged.
#'
#' @examples
#' panel <- data.frame(
#'   cpr  = c("a", "a", "a", "b", "b", "c"),
#'   year = c(2020, 2021, 2022, 2020, 2022, 2022)
#' )
#'
#' # Not balanced: b lacks 2021, c lacks 2020 and 2021
#' expect_balanced(panel, cpr, year)
#'
#' # Only gaps: b lacks 2021; c simply entered in 2022
#' expect_balanced(panel, cpr, year, gaps_only = TRUE)
#'
#' # A year missing for everyone is only found with explicit periods
#' expect_balanced(panel, cpr, year, periods = 2019:2022, gaps_only = TRUE)
#'
#' @seealso [expect_unique()] for duplicated unit-periods,
#'   [expect_no_overlap()] for spell data, [expect_empty()].
#'
#' @export
expect_balanced <- function(data, id, time,
                            periods     = NULL,
                            gaps_only   = FALSE,
                            success_msg = NULL,
                            warn_msg    = NULL,
                            abort_msg   = NULL,
                            log         = getOption("daos.check_log"),
                            dump        = getOption("daos.check_dump")) {

  check_data_frame(data)
  ids      <- names(dplyr::select(data, {{ id }}))
  time_col <- names(dplyr::select(data, {{ time }}))
  if (length(ids) == 0) cli::cli_abort("{.arg id} must select at least one column.")
  if (length(time_col) != 1) cli::cli_abort("{.arg time} must select exactly one column.")

  missing_periods <- find_panel_gaps(data, ids, time_col, periods, gaps_only)

  what  <- if (gaps_only) "Gaps in panel" else "Panel is not balanced"
  label <- abort_msg %||% warn_msg
  report_check(
    violations  = missing_periods,
    success_msg = success_msg %||%
      if (!is.null(label)) paste0("Check passed: ", label)
      else if (gaps_only) paste0("No gaps in ", time_col, " per ", toString(ids))
      else paste0("Balanced panel: ", toString(ids), " by ", time_col),
    fail_msg    = label %||%
      paste0(what, ": missing ", toString(ids), "-", time_col, " combinations"),
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump
  )
  invisible(data)
}

# Unit-periods that should exist but don't, as a tibble of id + time columns.
find_panel_gaps <- function(data, ids, time_col, periods, gaps_only) {
  obs <- data.table::as.data.table(data)[, c(ids, time_col), with = FALSE]
  obs <- obs[!is.na(obs[[time_col]])]
  periods <- sort(unique(periods %||% obs[[time_col]]))
  obs <- unique(obs[obs[[time_col]] %in% periods])
  data.table::setorderv(obs, c(ids, time_col))

  # One group per unit; counting before expanding keeps the grid small
  unit   <- data.table::rleidv(obs, cols = ids)
  first  <- !duplicated(unit)
  n_seen <- tabulate(unit)
  pos    <- match(obs[[time_col]], periods)
  lo     <- if (gaps_only) pos[first] else rep(1L, sum(first))
  hi     <- if (gaps_only) pos[!duplicated(unit, fromLast = TRUE)] else rep(length(periods), sum(first))
  bad    <- which(n_seen < hi - lo + 1L)

  units <- obs[first, ids, with = FALSE][bad]
  span  <- hi[bad] - lo[bad] + 1L
  grid  <- units[rep(seq_len(nrow(units)), times = span)]
  data.table::set(grid, j = time_col,
                  value = periods[sequence(span, from = lo[bad])])

  tibble::as_tibble(grid[!obs, on = c(ids, time_col)])
}
