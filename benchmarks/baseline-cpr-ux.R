# Snapshot before native CPR optimisation, for reproducible comparisons.
#' Standardise CPR numbers
#'
#' Cleans a vector of Danish CPR numbers to the canonical 10-digit form:
#' dashes and spaces are stripped, and nine-digit values consisting only of
#' digits are zero-padded on the left. The padding is well-founded: birth
#' days 01-09 mean that roughly a third of all CPR numbers legitimately
#' start with a zero, which Excel silently drops from numeric cells.
#'
#' This is standardisation only, not validation. Values that cannot be
#' brought to 10 digits are returned cleaned but otherwise untouched, so a
#' malformed number stays visibly malformed for downstream checks. Use
#' [daos::add_cpr_info()] for validity, or pipe through a checkpoint
#' (see `vignette("validation")`).
#'
#' [daos::add_cpr_info()] applies this cleaning internally for its
#' calculations, while preserving the original CPR column in its output.
#'
#' @param x A character vector of CPR numbers. Numeric vectors are
#'   converted with `as.character()` first.
#'
#' @return A character vector of the same length.
#'
#' @examples
#' clean_cpr(c("111111-1118", "1111111118", "101004007", NA))
#'
#' # Typical use: standardise the join key on both sides
#' # df  |> dplyr::mutate(pnr = clean_cpr(pnr))
#'
#' @seealso [daos::add_cpr_info()], [daos::clean_cvr()]
#'
#' @export
clean_cpr <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  x <- gsub("[- ]", "", x)
  pad <- !is.na(x) & grepl("^\\d{9}$", x, perl = TRUE)
  x[pad] <- paste0("0", x[pad])
  x
}

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
  values <- lapply(seq_along(specs), function(i) {
    spec <- specs[[i]]
    if (spec$type == "age") {
      ref <- .cpr_reference(spec$reference, data, output[i])
      result <- if (is.null(ref$at)) {
        .cpr_compute(data[[source]], add = "age", ref_date = ref$value)
      } else {
        .cpr_compute(data[[source]], add = "age", ref_date = ref$value, at = ref$at)
      }
    } else {
      result <- .cpr_compute(data[[source]], add = spec$type)
    }
    result[[spec$type]]
  })
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
#'   the input data. Defaults to 1 January of each year.
#' @param at Point in the year: `"primo"` (1 January), `"medio"` (1 July),
#'   or `"ultimo"` (31 December). Only allowed with `year`.
#' @param date A Date vector or strict ISO date strings (`YYYY-MM-DD`).
#'   Supply either `year` or `date`. With neither, uses `Sys.Date()`.
#' @details References may have length one or one value per input row.
#' Missing references produce missing ages. Data columns take precedence
#' over caller variables; `.env` and `.data` can make the source explicit.
#' @return An age specification for [daos::add_cpr_info()].
#' @examples
#' df <- data.frame(pnr = "0101004007", year = 2025L)
#' add_cpr_info(df, pnr, age(year), sex)
#' add_cpr_info(df, pnr, alder = age(date = "2025-07-01"))
#' @export
age <- function(year, at = "primo", date) {
  if (!missing(year) && !missing(date)) cli::cli_abort("Supply only one of year and date in age().")
  if (missing(year) && !missing(at)) cli::cli_abort("at is only supported with year in age().")
  at <- rlang::arg_match(at, c("primo", "medio", "ultimo"))
  use_year <- !missing(year)
  reference <- if (use_year) rlang::enquo(year) else if (!missing(date)) rlang::enquo(date) else rlang::quo(Sys.Date())
  structure(list(reference = reference, year = use_year, at = at), class = "daos_cpr_age")
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
    return(list(value = value, at = spec$at))
  }
  if (is.character(value)) {
    parsed <- suppressWarnings(as.Date(value, format = "%Y-%m-%d"))
    bad <- !is.na(value) & (is.na(parsed) | !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value) |
      format(parsed, "%Y-%m-%d") != value)
    if (any(bad)) cli::cli_abort("date for {.var {output}} must contain valid ISO dates (YYYY-MM-DD).")
    value <- parsed
  }
  if (!inherits(value, "Date") || any(!is.na(value) & !is.finite(value))) {
    cli::cli_abort("date for {.var {output}} must be a Date vector or ISO date strings; use age(year = ...) for numeric years.")
  }
  list(value = value, at = NULL)
}

# The calculation engine is separate from selection parsing and validation.
.cpr_compute <- function(cpr, add, ref_date = Sys.Date(), at = "primo") {
  if ("age" %in% add) {
    if (is.numeric(ref_date) && !is.object(ref_date)) {
      ref_year <- ref_date
      ref_md <- switch(at, primo = 101L, medio = 701L, ultimo = 1231L)
    } else {
      ref <- as.POSIXlt(ref_date)
      ref_year <- ref$year + 1900L
      ref_md <- (ref$mon + 1L) * 100L + ref$mday
    }
  }
  cpr_clean <- clean_cpr(cpr)
  alle <- list()

  format_ok <- grepl("^\\d{10}$", cpr_clean, perl = TRUE)

  # The single string-to-number conversion. A 10-digit value is < 2^53, so
  # it is exactly representable in a double and all integer arithmetic on
  # it is exact. Invalid rows become NA here and propagate through every
  # computation below for free.
  num <- rep(NA_real_, length(cpr_clean))
  num[format_ok] <- as.numeric(cpr_clean[format_ok])

  if ("mod11" %in% add) {
    D <- outer(num, 10^(9:0), function(n, p) (n %/% p) %% 10)
  }

  if (any(add %in% c("bday", "age", "sex", "valid"))) {
    if ("mod11" %in% add) {
      dag    <- D[, 1L] * 10 + D[, 2L]
      maaned <- D[, 3L] * 10 + D[, 4L]
      aar2   <- D[, 5L] * 10 + D[, 6L]
      d7     <- D[, 7L]
    } else {
      dag    <- num %/% 10^8
      maaned <- (num %/% 10^6) %% 100
      aar2   <- (num %/% 10^4) %% 100
      d7     <- (num %/% 10^3) %% 10
    }

    # Official century rules (digit 7 crossed with the two-digit year):
    #
    #   d7    | yy 00-36 | yy 37-57 | yy 58-99
    #   ------|----------|----------|----------
    #   0-3   | 1900     | 1900     | 1900
    #   4, 9  | 2000     | 1900     | 1900
    #   5-8   | 2000     | 2000     | 1800
    #
    # Encoded branchlessly: start at 1900 and shift by +-100 where the table
    # says so. Logical vectors act as 0/1, so this is three vector ops.
    aarhundrede <- 1900 +
      100 * ((d7 == 4 | d7 == 9) & aar2 <= 36) +
      100 * (d7 >= 5 & d7 <= 8 & aar2 <= 57) -
      100 * (d7 >= 5 & d7 <= 8 & aar2 >= 58)

    aar <- aarhundrede + aar2

    # Calendar validation in pure arithmetic: clamp the month for safe table
    # lookup, then check the day against the month length (+1 for February
    # in leap years).
    skudaar   <- (aar %% 4 == 0 & aar %% 100 != 0) | aar %% 400 == 0
    maaned_ok <- maaned >= 1 & maaned <= 12
    midx      <- maaned
    midx[which(!maaned_ok)] <- 1
    maks_dag  <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[midx] +
      (maaned == 2) * skudaar
    dato_ok   <- maaned_ok & dag >= 1 & dag <= maks_dag

    gyldig <- !is.na(dato_ok) & dato_ok

    # Date construction without parsing: convert (year, month, day) straight
    # to days since 1970-01-01 (Hinnant's civil-days algorithm) and stamp the
    # Date class on. This skips strptime entirely.
    if ("bday" %in% add) {
      dage <- .cpr_days_from_civil(aar, maaned, dag)
      dage[!gyldig] <- NA_real_
      alle$bday <- structure(as.double(dage), class = "Date")
    }
    if ("sex" %in% add) {
      koen <- as.integer(num %% 2)
      koen[!gyldig] <- NA_integer_
      alle$sex <- koen
    }
    if ("age" %in% add) {
      alder <- as.integer(ref_year - aar - (ref_md < maaned * 100 + dag))
      alder[!gyldig] <- NA_integer_
      alle$age <- alder
    }
    if ("valid" %in% add) alle$valid <- gyldig
  }

  # The mod-11 checksum for all rows at once: digit matrix times weight
  # vector is one BLAS call.
  if ("mod11" %in% add) {
    m11_vaegte <- c(4, 3, 2, 7, 6, 5, 4, 3, 2, 1)
    alle$mod11 <- as.vector(D %*% m11_vaegte) %% 11 == 0
  }

  alle[add]
}

# Days since 1970-01-01 from (year, month, day), fully vectorised integer
# arithmetic. This is Howard Hinnant's days_from_civil algorithm
# (https://howardhinnant.github.io/date_algorithms.html): years are shifted
# so March is month 0 (putting the leap day last), and the day-of-year for
# the shifted month follows the linear pattern (153 * m + 2) %/% 5.
.cpr_days_from_civil <- function(y, m, d) {
  y   <- y - (m <= 2)
  era <- y %/% 400
  yoe <- y - era * 400
  mp  <- (m + 9) %% 12
  doy <- (153 * mp + 2) %/% 5 + d - 1
  doe <- yoe * 365 + yoe %/% 4 - yoe %/% 100 + doy
  era * 146097 + doe - 719468
}
