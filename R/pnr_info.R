#' Extract information from Danish CPR numbers
#'
#' Vectorised extraction of birth date, age, sex, sequential number, and
#' validity indicators from Danish CPR (Civil Person Register) numbers.
#' Returns the original data frame with the requested columns appended.
#'
#' @details
#' **Supported info types** (`add` values):
#'
#' | Type | Output | Description |
#' |------|--------|-------------|
#' | `"bday"` | Date | Date of birth |
#' | `"age"` | integer | Age in whole years at `ref_date` |
#' | `"sex"` | character | `"mand"` (male) or `"kvinde"` (female) |
#' | `"pnum"` | integer | Sequential (running) number (digits 7–10) |
#' | `"mod11"` | logical | Modulus-11 check (weights 4,3,2,7,6,5,4,3,2,1) |
#' | `"valid"` | logical | Format valid *and* birth date parseable |
#'
#' **Century detection** follows the official CPR Register rules based on
#' digit 7 and the two-digit year component.
#'
#' **Input tolerance:** dashes and spaces are stripped automatically.
#' Nine-digit numbers are zero-padded on the left (recovering values that
#' lost a leading zero in Excel).
#'
#' @param data A tibble or data frame.
#' @param cpr_col Name of the CPR column (unquoted).
#' @param add Which info types to add. Either:
#'   - An **unnamed** character vector, e.g. `c("bday", "age")` — uses the
#'     type names as column names.
#'   - A **named** character vector, e.g. `c(birth_date = "bday",
#'     years_old = "age")` — left-hand side becomes the column name,
#'     right-hand side is the type.
#'   Default: all six types.
#' @param ref_date Reference date for age calculation. Accepts a `Date`
#'   object or an ISO-format string (`"YYYY-MM-DD"`). Default: `Sys.Date()`.
#'
#' @return The original data frame with the requested columns appended.
#'
#' @examples
#' df <- data.frame(
#'   pnr = c("1111111118", "111111-1118", "111111118"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Default: add all columns
#' cpr_info(df, pnr)
#'
#' # Custom column names:
#' cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#'
#' # Unnamed — uses type names directly:
#' cpr_info(df, pnr, add = c("bday", "sex"))
#'
#' @importFrom cli cli_abort
#' @importFrom rlang as_name enquo
#' @importFrom dplyr case_when if_else bind_cols
#' @importFrom tibble as_tibble
#' @export
cpr_info <- function(
    data,
    cpr_col,
    add      = c("bday", "age", "sex", "pnum", "mod11", "valid"),
    ref_date = Sys.Date()
) {

  gyldige_typer <- c("bday", "age", "sex", "pnum", "mod11", "valid")

  if (is.null(names(add))) {
    names(add) <- add
  } else {
    mangler_navn <- names(add) == "" | is.na(names(add))
    names(add)[mangler_navn] <- add[mangler_navn]
  }

  ukendt <- setdiff(add, gyldige_typer)
  if (length(ukendt) > 0) {
    cli::cli_abort(c(
      "Unknown info type in {.var add}: {.val {ukendt}}",
      "i" = "Valid values: {.val {gyldige_typer}}"
    ))
  }

  if (is.character(ref_date)) {
    ref_date <- as.Date(ref_date)
    if (is.na(ref_date)) {
      cli::cli_abort("{.var ref_date} could not be parsed as a date (expected ISO format, e.g. {.val 2020-01-01})")
    }
  } else if (!inherits(ref_date, "Date")) {
    cli::cli_abort("{.var ref_date} must be a string or a {.cls Date} object")
  }

  cpr_navn <- rlang::as_name(rlang::enquo(cpr_col))
  if (!cpr_navn %in% names(data)) {
    cli::cli_abort("Column {.var {cpr_navn}} not found in data.")
  }

  cpr <- data[[cpr_navn]]
  if (!is.character(cpr)) cpr <- as.character(cpr)

  cpr_clean <- gsub("[- ]", "", cpr)

  needs_pad <- nchar(cpr_clean) == 9L & !grepl("\\D", cpr_clean)
  cpr_clean[needs_pad] <- paste0("0", cpr_clean[needs_pad])

  format_ok <- nchar(cpr_clean) == 10L & !grepl("\\D", cpr_clean)

  cpr_safe <- ifelse(format_ok, cpr_clean, "0000000000")

  d1  <- as.integer(substr(cpr_safe,  1L,  1L))
  d2  <- as.integer(substr(cpr_safe,  2L,  2L))
  d3  <- as.integer(substr(cpr_safe,  3L,  3L))
  d4  <- as.integer(substr(cpr_safe,  4L,  4L))
  d5  <- as.integer(substr(cpr_safe,  5L,  5L))
  d6  <- as.integer(substr(cpr_safe,  6L,  6L))
  d7  <- as.integer(substr(cpr_safe,  7L,  7L))
  d8  <- as.integer(substr(cpr_safe,  8L,  8L))
  d9  <- as.integer(substr(cpr_safe,  9L,  9L))
  d10 <- as.integer(substr(cpr_safe, 10L, 10L))

  dag    <- d1 * 10L + d2
  maaned <- d3 * 10L + d4
  aar2   <- d5 * 10L + d6
  loebe  <- ((d7 * 10L + d8) * 10L + d9) * 10L + d10

  aarhundrede <- dplyr::case_when(
    d7 <= 3L                  ~ 1900L,
    d7 == 4L & aar2 <= 36L   ~ 2000L,
    d7 == 4L & aar2 >= 37L   ~ 1900L,
    d7 %in% 5:8 & aar2 <= 57L ~ 2000L,
    d7 %in% 5:8 & aar2 >= 58L ~ 1800L,
    d7 == 9L & aar2 <= 36L   ~ 2000L,
    d7 == 9L & aar2 >= 37L   ~ 1900L,
    TRUE                      ~ NA_integer_
  )

  aar          <- aarhundrede + aar2
  foedselsdato <- as.Date(ISOdate(aar, maaned, dag, tz = "UTC"))
  koen         <- ifelse(d10 %% 2L == 1L, "mand", "kvinde")

  sum_m11 <- d1 * 4L + d2 * 3L + d3 * 2L +
    d4 * 7L + d5 * 6L + d6 * 5L +
    d7 * 4L + d8 * 3L + d9 * 2L +
    d10
  m11_ok <- (sum_m11 %% 11L) == 0L

  alder <- as.integer(format(ref_date, "%Y")) - aar -
    (format(ref_date, "%m-%d") < format(foedselsdato, "%m-%d"))

  gyldig <- format_ok & !is.na(foedselsdato)

  alle <- list(
    bday  = dplyr::if_else(gyldig,    foedselsdato, as.Date(NA)),
    age   = dplyr::if_else(gyldig,    alder,        NA_integer_),
    sex   = dplyr::if_else(gyldig,    koen,         NA_character_),
    pnum  = dplyr::if_else(gyldig,    loebe,        NA_integer_),
    mod11 = dplyr::if_else(format_ok, m11_ok,       NA),
    valid = gyldig
  )

  valgt <- alle[unname(add)]
  names(valgt) <- names(add)

  dplyr::bind_cols(data, tibble::as_tibble(valgt))
}
