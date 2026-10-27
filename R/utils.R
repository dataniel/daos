check_data_frame <- function(data, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.",
      call = call
    )
  }
}

format_elapsed <- function(x) {
  secs <- as.numeric(x, units = "secs")
  if (secs < 1) paste0(round(secs * 1000), "ms")
  else if (secs < 60) paste0(round(secs, 1), "s")
  else paste0(round(secs / 60, 1), "m")
}
