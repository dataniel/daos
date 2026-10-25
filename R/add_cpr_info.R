#' Add information derived from Danish CPR numbers
#'
#' Add selected CPR information without changing the original CPR column.
#'
#' @param data A data frame or tibble.
#' @param cpr_col CPR column, unquoted or a literal column-name string.
#' @param ... Information to add: `bday`, `sex`, `valid`, `mod11`, `age`, or
#'   [daos::age()] with a reference year or date. Name a selection to choose its
#'   output column, e.g. `birth_date = bday`. With no selections, adds
#'   `bday`, `age`, `sex`, `mod11`, and `valid`. Bare `age` uses today's date.
#' @param overwrite Allow replacing existing output columns? Default `FALSE`.
#'   The CPR source column cannot be replaced.
#'
#' @details
#' `bday` is a Date; `age` is completed calendar years (integer); `sex` is
#' integer 1 for an odd final digit (male), 0 for even (female).
#' `valid` checks ten digits and a real encoded calendar date, not whether
#' the number was assigned to a person. Missing and malformed CPRs give
#' `valid = FALSE` and missing birth date, age, and sex.
#' `mod11` is a separate logical checksum, not a requirement for `valid`.
#' Malformed formats give a missing checksum.
#'
#' CPR values are cleaned internally with [daos::clean_cpr()]. To also standardise
#' the source column, use `dplyr::mutate(pnr = clean_cpr(pnr))` explicitly.
#' Rows, row order, and input columns are preserved unless `overwrite = TRUE`.
#' Duplicate output names are always an error.
#'
#' CPR parsing, calendar validation, and requested outputs share a single
#' native pass. Multiple age selections reuse the decoded birth date.
#' Pre-cleaning is optional: use [daos::clean_cpr()] when the source column
#' itself must be standardised for joins or export.
#'
#' For 29 February births, age advances on 1 March in non-leap years.
#' A reference before birth gives a negative age. Use an explicit reference
#' for reproducible analysis; today's date changes between runs.
#'
#' This selection API replaces `add`, `ref_date`, `year`, and `at` arguments:
#' use `age(year, "primo")` or `age(date = reference_date)` instead.
#' Unlike the previous API, the source CPR column is preserved.
#'
#' @return The input data frame with selected columns added in selection order.
#' @examples
#' df <- data.frame(pnr = c("0101004007", "111111-1118"), year = 2024:2025)
#' add_cpr_info(df, pnr)
#' add_cpr_info(df, pnr, sex, birth_date = bday)
#' add_cpr_info(df, pnr,
#'   primoalder = age(year), ultimoalder = age(year, "ultimo"), sex)
#' add_cpr_info(df, pnr, alder = age(date = "2025-07-01"))
#' @seealso [daos::age()], [daos::clean_cpr()]
#' @useDynLib daos, .registration = TRUE, .fixes = "C_"
#' @export
add_cpr_info <- function(data, cpr_col, ..., overwrite = FALSE) {
  if (!is.data.frame(data)) cli::cli_abort("{.arg data} must be a data frame or tibble.")
  if (anyNA(names(data)) || any(names(data) == "") || anyDuplicated(names(data))) {
    cli::cli_abort("{.arg data} must have unique, non-empty column names.")
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    cli::cli_abort("{.arg overwrite} must be TRUE or FALSE.")
  }
  col <- rlang::enquo(cpr_col)
  if (!rlang::quo_is_symbol(col) && !rlang::is_string(rlang::quo_get_expr(col))) {
    cli::cli_abort("{.arg cpr_col} must be an unquoted column name or a single string.")
  }
  source <- rlang::as_name(col)
  if (!source %in% names(data)) cli::cli_abort("Column {.var {source}} not found in data.")
  if (!is.atomic(data[[source]]) || !is.null(dim(data[[source]]))) {
    cli::cli_abort("The CPR column must be an atomic vector.")
  }
  selections <- rlang::enquos(..., .ignore_empty = "none")
  legacy <- intersect(names(selections), c("add", "ref_date", "year", "at"))
  types <- c("bday", "age", "sex", "mod11", "valid")
  if (!length(selections)) {
    selections <- lapply(types, function(x) rlang::new_quosure(rlang::sym(x)))
    names(selections) <- rep("", length(types))
  }
  specs <- lapply(selections, function(q) {
    if (rlang::quo_is_missing(q)) cli::cli_abort("Empty CPR selection. Remove the extra comma or choose an information type.")
    expr <- rlang::quo_get_expr(q)
    if (rlang::is_symbol(expr) && rlang::as_string(expr) %in% types) {
      type <- rlang::as_string(expr)
      return(list(type = type, reference = if (type == "age") age() else NULL))
    }
    is_age <- rlang::is_call(expr, "age") ||
      (is.call(expr) && identical(expr[[1L]], quote(daos::age)))
    if (!is_age) {
      if (length(legacy)) {
        cli::cli_abort(c("The CPR selection API has changed.",
          "i" = 'Use bare selections such as sex and bday, age(year, "primo"), or age(date = reference_date).',
          "i" = "Name outputs with alder = age(year). The old add/ref_date/year/at arguments are no longer supported."))
      }
      label <- rlang::as_label(q)
      cli::cli_abort(c("Unknown CPR selection: {.val {label}}.",
        "i" = 'Choose bday, sex, valid, mod11, age, or age(year, "primo").'))
    }
    # Resolve our helper explicitly; capture its arguments in the caller's
    # environment and evaluate references against data only afterwards.
    expr[[1L]] <- quote(.cpr_age_helper)
    env <- rlang::env(rlang::quo_get_env(q), .cpr_age_helper = age)
    list(type = "age", reference = rlang::eval_bare(expr, env))
  })
  output <- names(selections)
  unnamed <- output == ""
  output[unnamed] <- vapply(specs[unnamed], `[[`, character(1), "type")
  if (anyDuplicated(output)) {
    cli::cli_abort(c("Duplicate output column names.",
      "i" = 'Give each selection a unique name, e.g. primoalder = age(year), ultimoalder = age(year, "ultimo").'))
  }
  if (source %in% output) cli::cli_abort("The CPR source column {.var {source}} cannot be overwritten. Choose another output name.")
  collisions <- intersect(output, names(data))
  if (length(collisions) && !overwrite) {
    cli::cli_abort(c("Output columns already exist: {.var {collisions}}.",
      "i" = "Choose different output names or set overwrite = TRUE."))
  }
  codes <- match(vapply(specs, `[[`, character(1), "type"), types) - 1L
  references <- lapply(seq_along(specs), function(i) {
    if (specs[[i]]$type == "age") .cpr_reference(specs[[i]]$reference, data, output[i]) else NULL
  })
  cpr <- data[[source]]
  if (!is.character(cpr)) cpr <- as.character(cpr)
  values <- .Call(C_daos_cpr_info, cpr, codes, references)
  # Compute against the original data, before any output is assigned.
  result <- if (inherits(data, "data.table")) data.table::copy(data) else data
  for (i in seq_along(output)) result[[output[i]]] <- values[[i]]
  result
}

#' Specify an age calculation for CPR information
#'
#' Use inside [daos::add_cpr_info()] to choose the reference for an age column.
#' This helper describes a calculation; it does not calculate an age itself.
#' @param year Numeric whole year(s), directly or as a column/expression in
#'   the input data. Defaults to 31 December of the previous year.
#' @param at Point in the year: `"primo"` (uses the `primo` convention), `"medio"` (1 July),
#'   or `"ultimo"` (31 December). Only allowed with `year`.
#' @param date A Date vector or strict ISO date strings (`YYYY-MM-DD`).
#'   Supply either `year` or `date`. With neither, uses `Sys.Date()`.
#' @param primo Convention for `at = "primo"`: `"previous_ultimo"` (default)
#'   uses 31 December of `year - 1`; `"jan1"` uses 1 January of `year`.
#'   Only allowed with `year` and `at = "primo"` (including its default).
#' @details References may have length one or one value per input row.
#' Missing references produce missing ages. Data columns take precedence
#' over caller variables; `.env` and `.data` can make the source explicit.
#' For population statistics where opening ages must equal the previous
#' closing ages, use `age(year, primo = "previous_ultimo")`. This is equivalent
#' to `age(year - 1L, "ultimo")` and excludes birthdays on 1 January of `year`.
#' It changes the age reference only, not membership of the population.
#' @return An age specification for [daos::add_cpr_info()].
#' @examples
#' df <- data.frame(pnr = "0101004007", year = 2025L)
#' add_cpr_info(df, pnr, age(year), sex)
#' add_cpr_info(df, pnr, alder = age(date = "2025-07-01"))
#' add_cpr_info(df, pnr, primoalder = age(year, primo = "previous_ultimo"))
#' @export
age <- function(year, at = "primo", date, primo = "previous_ultimo") {
  if (!missing(year) && !missing(date)) cli::cli_abort("Supply only one of year and date in age().")
  if (missing(year) && !missing(at)) cli::cli_abort("at is only supported with year in age().")
  at <- rlang::arg_match(at, c("primo", "medio", "ultimo"))
  if (!missing(primo) && (missing(year) || at != "primo"))
    cli::cli_abort("primo is only supported with year and at = 'primo' in age().")
  primo <- rlang::arg_match(primo, c("jan1", "previous_ultimo"))
  use_year <- !missing(year)
  reference <- if (use_year) rlang::enquo(year) else if (!missing(date)) rlang::enquo(date) else rlang::quo(Sys.Date())
  structure(list(reference = reference, year = use_year, at = at, primo = primo), class = "daos_cpr_age")
}

.cpr_reference <- function(spec, data, output) {
  value <- tryCatch(rlang::eval_tidy(spec$reference, data), error = function(e) {
    cli::cli_abort("Cannot evaluate the age reference for {.var {output}}.", parent = e)
  })
  if (!length(value) %in% c(1L, nrow(data)) || !is.null(dim(value))) {
    cli::cli_abort("Reference for {.var {output}} must have length 1 or one value per row ({nrow(data)}).")
  }
  if (spec$year) {
    if (!is.numeric(value) || is.object(value) || any(!is.na(value) &
        (!is.finite(value) | value != trunc(value) | value < 1 | value > 9999))) {
      cli::cli_abort("year for {.var {output}} must contain numeric whole years between 1 and 9999.")
    }
    if (spec$at == "primo" && spec$primo == "previous_ultimo") {
      if (any(value < 2, na.rm = TRUE))
        cli::cli_abort("year must be at least 2 when primo = 'previous_ultimo'.")
      return(list(as.double(value) - 1, 0L, 1231L, output))
    }
    return(list(as.double(value), 0L, switch(spec$at, primo = 101L, medio = 701L, ultimo = 1231L), output))
  }
  if (is.character(value)) return(list(value, 2L, 0L, output))
  if (!inherits(value, "Date") || any(!is.na(value) & !is.finite(value))) {
    cli::cli_abort("date for {.var {output}} must be a Date vector or ISO date strings; use age(year = ...) for numeric years.")
  }
  list(as.double(value), 1L, 0L, output)
}
