# Scope filters preserve the original keys and row indices, including flags.
screen_ts_time_scope <- function(x) {
  display <- if (inherits(x, "POSIXt")) as.POSIXct(x) else if (
    inherits(x, c("Date", "yearmonth", "yearquarter", "yearweek"))) as.Date(x) else if (
    is.numeric(x)) x else NULL
  coordinates <- as.numeric(display)
  valid <- which(is.finite(coordinates))
  bounds <- if (length(valid)) display[valid[c(which.min(coordinates[valid]), which.max(coordinates[valid]))]] else NULL
  list(coordinates = coordinates, bounds = bounds,
    enabled = length(bounds) == 2L && as.numeric(bounds[1]) < as.numeric(bounds[2]))
}

screen_ts_scope_rows <- function(prepared, time_scope, selected_range = NULL) {
  if (!time_scope$enabled || is.null(selected_range)) return(prepared$rows)
  bounds <- as.numeric(selected_range)
  if (length(bounds) != 2L || any(!is.finite(bounds)) || bounds[1] > bounds[2]) {
    return(lapply(prepared$rows, function(i) integer()))
  }
  # The full view retains unknown times so diagnostics can still report them.
  if (bounds[1] <= as.numeric(time_scope$bounds[1]) &&
      bounds[2] >= as.numeric(time_scope$bounds[2])) return(prepared$rows)
  t <- time_scope$coordinates
  keep <- is.finite(t) & t >= bounds[1] & t <= bounds[2]
  lapply(prepared$rows, function(i) i[keep[i]])
}

screen_ts_scope_indices <- function(prepared, selected, rows = prepared$rows) {
  keep <- lengths(rows) > 0L
  for (j in seq_along(prepared$codes)) {
    if (length(selected[[j]])) keep <- keep & as.character(prepared$codes[[j]]) %in% selected[[j]]
  }
  which(keep)
}
