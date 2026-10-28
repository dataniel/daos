check_data_frame <- function(data, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame or tibble, not {.cls {class(data)}}.",
      call = call
    )
  }
}
