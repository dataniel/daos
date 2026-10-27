check_data_frame <- function(data, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.",
      call = call
    )
  }
}

# At most `n` bullets plus "... and N more", so a long list of problems stays
# one screen. Braces are doubled so values are shown literally, not
# interpolated by cli.
cap_bullets <- function(x, bullet = "x", n = 10) {
  shown <- gsub("([{}])", "\\1\\1", x[seq_len(min(n, length(x)))])
  names(shown) <- rep(bullet, length(shown))
  more <- length(x) - length(shown)
  c(shown, if (more > 0) c(" " = paste0("... and ", more, " more")))
}

format_elapsed <- function(x) {
  secs <- as.numeric(x, units = "secs")
  if (secs < 1) paste0(round(secs * 1000), "ms")
  else if (secs < 60) paste0(round(secs, 1), "s")
  else paste0(round(secs / 60, 1), "m")
}
