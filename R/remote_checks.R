# Checkpoints on database and Arrow tables --------------------------------
#
# A lazy table (dbplyr, e.g. DuckDB) is checked where it lives: the violation
# set is built as a query, and only its size, the preview rows and, with
# `dump`, the full set are fetched into R. Arrow tables and datasets go
# through DuckDB with arrow::to_duckdb(), so there is one code path. dbplyr,
# duckdb and arrow are only suggested: a data frame never needs them.

#' @importFrom rlang .data
NULL

# The table to check: a data frame as it is, anything else as a lazy table.
check_table <- function(data, call = rlang::caller_env()) {
  if (is.data.frame(data)) return(data)
  if (inherits(data, "tbl_lazy")) {
    rlang::check_installed("dbplyr", "to check a database table.", call = call)
    return(data)
  }
  if (inherits(data, c("ArrowTabular", "Dataset", "arrow_dplyr_query"))) {
    rlang::check_installed(c("duckdb", "dbplyr"), "to check an Arrow table.", call = call)
    return(arrow::to_duckdb(data))
  }
  cli::cli_abort(
    "{.arg data} must be a data frame, a database table or an Arrow table, not {.cls {class(data)}}.",
    call = call
  )
}

is_remote <- function(data) !is.data.frame(data)

# Column names of a selection; names() of a lazy table are its internals.
select_names <- function(data, ...) colnames(dplyr::select(data, ...))

remote_nrow <- function(x) {
  n <- dplyr::pull(dplyr::summarise(dplyr::ungroup(x), .daos_n = dplyr::n()))
  as.numeric(n)
}

# DENSE_RANK() over the given columns. dbplyr's dense_rank() takes a single
# column, and the numbering of duplicate and overlap groups needs several.
sql_dense_rank <- function(tbl, cols) {
  con <- dbplyr::remote_con(tbl)
  cols <- DBI::dbQuoteIdentifier(con, cols)
  dbplyr::sql(paste0(
    "DENSE_RANK() OVER (ORDER BY ",
    paste0("CASE WHEN ", cols, " IS NULL THEN 0 ELSE 1 END, ", cols, collapse = ", "),
    ")"
  ))
}

# Rows whose key occurs more than once, numbered by `dupid` in key order.
# A database has no row order, so groups cannot be numbered by first
# appearance as in memory. NULL keys form a group, as NA keys do in memory.
remote_duplicates <- function(tbl, cols) {
  dups <- tbl |>
    dplyr::select(!dplyr::any_of("dupid")) |>
    dplyr::group_by(!!!rlang::syms(cols)) |>
    dplyr::filter(dplyr::n() > 1L) |>
    dplyr::ungroup()
  dups |>
    dplyr::mutate(dupid = !!sql_dense_rank(dups, cols)) |>
    sort_by(rlang::exprs(.data$dupid))
}

# Missing unit-periods, as find_panel_gaps() but as one query. The periods
# travel inline with their positions, so nothing is written to the database.
remote_panel_gaps <- function(tbl, ids, time_col, periods, gaps_only) {
  obs <- tbl |>
    dplyr::select(dplyr::all_of(c(ids, time_col))) |>
    dplyr::filter(!is.na(.data[[time_col]]))
  if (is.null(periods)) {
    periods <- sort(dplyr::pull(dplyr::distinct(obs, .data[[time_col]])))
  } else {
    periods <- sort(unique(periods))
    obs <- dplyr::filter(obs, .data[[time_col]] %in% !!periods)
  }
  per <- tibble::tibble(!!time_col := periods, .daos_pos = seq_along(periods))
  per <- dbplyr::copy_inline(dbplyr::remote_con(tbl), per)
  obs <- dplyr::inner_join(dplyr::distinct(obs), per, by = time_col)

  units <- obs |>
    dplyr::group_by(!!!rlang::syms(ids)) |>
    dplyr::summarise(.daos_n  = dplyr::n(),
                     .daos_lo = min(.data$.daos_pos, na.rm = TRUE),
                     .daos_hi = max(.data$.daos_pos, na.rm = TRUE),
                     .groups = "drop")
  if (!gaps_only) {
    units <- dplyr::mutate(units, .daos_lo = 1L, .daos_hi = !!length(periods))
  }

  units |>
    dplyr::filter(.data$.daos_n < .data$.daos_hi - .data$.daos_lo + 1L) |>
    dplyr::cross_join(per) |>
    dplyr::filter(.data$.daos_pos >= .data$.daos_lo, .data$.daos_pos <= .data$.daos_hi) |>
    dplyr::select(dplyr::all_of(c(ids, time_col))) |>
    dplyr::anti_join(dplyr::select(obs, dplyr::all_of(c(ids, time_col))),
                     by = c(ids, time_col), na_matches = "na") |>
    sort_by(na_first(c(ids, time_col)))
}

# Overlapping spells, as find_overlaps() but with window functions: per
# unit, ordered by start, a spell opens a new group unless it starts on or
# before the latest end of the earlier spells, or an earlier spell is open.
remote_overlaps <- function(tbl, ids, start_col, end_col) {
  start <- rlang::sym(start_col)
  end   <- rlang::sym(end_col)

  spells <- tbl |>
    dplyr::filter(!is.na(!!start)) |>
    dplyr::group_by(!!!rlang::syms(ids)) |>
    dbplyr::window_order(!!start, !!end) |>
    dbplyr::window_frame(-Inf, -1) |>
    dplyr::mutate(
      .daos_prev_end  = max(!!end, na.rm = TRUE),
      .daos_prev_open = max(dplyr::if_else(is.na(!!end), 1L, 0L), na.rm = TRUE)
    ) |>
    dplyr::mutate(
      .daos_new = dplyr::if_else(
        dplyr::coalesce(.data$.daos_prev_open, 0L) == 1L, 0L,
        dplyr::if_else(is.na(.data$.daos_prev_end) | !!start > .data$.daos_prev_end, 1L, 0L)
      )
    ) |>
    dplyr::mutate(.daos_grp = cumsum(.data$.daos_new)) |>
    # the frame would otherwise carry into n() below
    dbplyr::window_frame(-Inf, Inf) |>
    dplyr::group_by(!!!rlang::syms(c(ids, ".daos_grp"))) |>
    dplyr::filter(dplyr::n() > 1L) |>
    dplyr::ungroup()

  spells |>
    dplyr::mutate(overlap_id = !!sql_dense_rank(spells, c(ids, ".daos_grp"))) |>
    dplyr::select(!dplyr::starts_with(".daos_")) |>
    sort_by(rlang::exprs(.data$overlap_id, !!start, !!end))
}

# The finders return their query unsorted, since a sorted query that is
# counted or summarised makes dbplyr warn, and attach the sort order for
# report_check() to apply when rows are fetched.
sort_by <- function(query, order) structure(query, daos_order = order)

# Sort keys putting NULL first, as data.table sorts NA, for arrange(). The
# CASE form works on every backend; NULLS FIRST does not (SQL Server).
na_first <- function(cols) {
  unlist(lapply(rlang::syms(cols), function(col) {
    list(rlang::expr(dplyr::if_else(is.na(!!col), 0L, 1L)), col)
  }), recursive = FALSE)
}

# Violation counts for all rules in one query. Rows have no numbers in a
# database, so there is no `rows` column.
remote_tally <- function(tbl, rules, call) {
  sums <- lapply(rules, function(rule) {
    rlang::quo(sum(dplyr::if_else(!!rule, 1L, 0L), na.rm = TRUE))
  })
  names(sums) <- paste0(".daos_r", seq_along(rules))
  counts <- tryCatch(
    dplyr::collect(dplyr::summarise(dplyr::ungroup(tbl), !!!sums)),
    error = function(e) {
      cli::cli_abort("The rules could not be evaluated in the database.",
                     parent = e, call = call)
    }
  )
  tibble::tibble(
    rule = names(rules),
    n    = as.integer(dplyr::coalesce(unlist(counts, use.names = FALSE), 0))
  )
}
