#' Assert that spells do not overlap within a unit
#'
#' A checkpoint for spell data, the other common shape of register data:
#' address periods, employment spells, benefit periods. Each unit can only be
#' in one spell at a time, so two spells for the same person that share a
#' day are an error. Returns `data`, so it can sit in the middle of a
#' pipeline.
#'
#' On failure the overlapping spells are reported with an `overlap_id`
#' column prepended, in the spirit of `dupid` in [flag_duplicates()]: spells
#' that overlap each other (directly or through a chain) share an id, so
#' each conflict can be inspected as a group.
#'
#' Spells are treated as closed intervals, as register dates usually are: a
#' spell ending 31 January and one starting 1 February do not overlap, while
#' one ending and one starting on 1 February do. A missing `end` means an
#' ongoing spell and overlaps everything after its start. Rows with a missing
#' `start` are ignored; check them with [expect_none()]`(data, is.na(start))`,
#' and spells that end before they start with
#' [expect_none()]`(data, end < start)`.
#'
#' @param data A data frame or tibble.
#' @param id Column(s) identifying the unit (tidy-select), e.g. `cpr`.
#' @param start,end Columns with the first and last period of each spell
#'   (dates, or integers such as years).
#' @inheritParams expect_empty
#' @param warn_msg Message shown (and logged) when spells overlap and no
#'   `abort_msg` is set. Defaults to a description of the check.
#'
#' @return `data` invisibly, unchanged.
#'
#' @examples
#' addresses <- data.frame(
#'   cpr   = c("a", "a", "b", "b"),
#'   start = as.Date(c("2020-01-01", "2021-01-01", "2020-01-01", "2020-06-01")),
#'   end   = as.Date(c("2020-12-31", NA,           "2020-06-30", "2021-12-31"))
#' )
#'
#' # b has two addresses in June 2020
#' expect_no_overlap(addresses, cpr, start, end)
#'
#' @seealso [expect_balanced()] for yearly panels, [expect_empty()].
#'
#' @export
expect_no_overlap <- function(data, id, start, end,
                              success_msg = NULL,
                              warn_msg    = NULL,
                              abort_msg   = NULL,
                              log         = getOption("daos.check_log"),
                              dump        = getOption("daos.check_dump")) {

  check_data_frame(data)
  ids       <- names(dplyr::select(data, {{ id }}))
  start_col <- names(dplyr::select(data, {{ start }}))
  end_col   <- names(dplyr::select(data, {{ end }}))
  if (length(ids) == 0) cli::cli_abort("{.arg id} must select at least one column.")
  if (length(start_col) != 1 || length(end_col) != 1) {
    cli::cli_abort("{.arg start} and {.arg end} must each select exactly one column.")
  }

  overlaps <- find_overlaps(data, ids, start_col, end_col)

  label <- abort_msg %||% warn_msg
  report_check(
    violations  = overlaps,
    success_msg = success_msg %||%
      if (is.null(label)) paste0("No overlapping spells per ", toString(ids))
      else paste0("Check passed: ", label),
    fail_msg    = label %||% paste0("Overlapping spells per ", toString(ids)),
    abort       = !is.null(abort_msg),
    log         = log,
    dump        = dump
  )
  invisible(data)
}

# Overlapping spells with an `overlap_id` per connected group of spells.
find_overlaps <- function(data, ids, start_col, end_col) {
  keys <- data.table::as.data.table(data)[, ids, with = FALSE]
  data.table::set(keys, j = ".start", value = as.numeric(data[[start_col]]))
  data.table::set(keys, j = ".row", value = seq_len(nrow(data)))
  keys <- keys[!is.na(keys$.start)]
  data.table::setorderv(keys, c(ids, ".start"))

  ends <- as.numeric(data[[end_col]])[keys$.row]
  ends[is.na(ends)] <- Inf
  unit <- data.table::rleidv(keys, cols = ids)
  n    <- length(unit)

  # A spell opens a new group unless it starts on or before the latest end
  # among the unit's earlier spells
  latest_end <- data.table::data.table(.unit = unit, .end = ends)[
    , .latest := cummax(.end), by = .unit]$.latest
  new_unit  <- c(TRUE, unit[-1] != unit[-n])
  new_group <- new_unit | keys$.start > c(-Inf, latest_end[-n])
  group     <- cumsum(new_group)
  hit       <- tabulate(group)[group] > 1

  out <- tibble::as_tibble(data[keys$.row[hit], , drop = FALSE])
  tibble::add_column(out, overlap_id = match(group[hit], unique(group[hit])),
                     .before = 1)
}
