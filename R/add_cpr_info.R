#' Add information derived from Danish CPR numbers
#'
#' Vectorised derivation of birth date, age, sex, and validity indicators
#' from Danish CPR (Civil Person Register) numbers.
#' Returns the original data frame with the requested columns appended.
#'
#' @details
#' **Supported info types** (`add` values):
#'
#' | Type | Output | Description |
#' |------|--------|-------------|
#' | `"bday"` | Date | Date of birth |
#' | `"age"` | integer | Age in whole years at `ref_date` |
#' | `"sex"` | integer | `1` (male, odd last digit) or `0` (female, even last digit) |
#' | `"mod11"` | logical | Modulus-11 check (weights 4,3,2,7,6,5,4,3,2,1) |
#' | `"valid"` | logical | Format valid *and* the encoded birth date is a real calendar date |
#'
#' **What `valid` means, and what it does not:**
#' `valid = TRUE` requires exactly two things: the cleaned value is ten
#' digits, and those digits encode a real calendar date under the official
#' century rules. **The modulus-11 check is *not* part of `valid`.** Since
#' 2007 the CPR office has assigned numbers *without* modulus-11 control,
#' because some birth dates have run out of mod-11-compatible sequence
#' numbers. cpr.dk states that these are "fuldt ud gyldige personnumre"
#' (so far assigned to persons born on certain 1 January dates between
#' 1960 and the 1990s). A failed mod-11 therefore does not make a CPR
#' number invalid. Validators that reject on mod-11 wrongly reject real,
#' living people. The check is still reported separately as `mod11`,
#' where it works as a data quality signal: a high failure rate in older
#' data suggests keying errors. The official assignment series start at
#' sequence number 0001, so `0000` never occurs in practice. It is not
#' rejected here, since the date check is the documented criterion.
#'
#' **Century detection** follows the official CPR rules based on digit 7
#' and the two-digit year component (see the table in the source code).
#'
#' **Input tolerance:** the CPR column is standardised with
#' [daos::clean_cpr()]: dashes and spaces are stripped and nine-digit
#' numbers are zero-padded on the left (recovering values that lost a
#' leading zero in Excel). The CPR column in the returned data frame is
#' always returned in the standardised 10-digit format `xxxxxxxxxx`.
#'
#' **Implementation note:** the function is plain vectorised arithmetic:
#' one string-to-number conversion, digits peeled into an n-by-10 matrix,
#' the mod-11 checksum as a single matrix product, and birth dates
#' constructed directly as epoch day counts (no date-string parsing).
#' It scales linearly to millions of rows.
#'
#' @param data A tibble or data frame.
#' @param cpr_col Name of the CPR column (unquoted).
#' @param add Which info types to add. Either:
#'   - An **unnamed** character vector, e.g. `c("bday", "age")`, which uses
#'     the type names as column names.
#'   - A **named** character vector, e.g. `c(birth_date = "bday",
#'     years_old = "age")`, where the left-hand side becomes the column
#'     name and the right-hand side is the type.
#'   Default: all five types.
#' @param ref_date Reference date for age calculation. Accepts a `Date`
#'   object or an ISO-format string (`"YYYY-MM-DD"`). Default: `Sys.Date()`.
#'
#' @return The original data frame with the requested columns appended.
#'
#' @references
#' CPR-kontoret, *Personnummeret i CPR-systemet* (1 July 2008),
#' <https://cdn2.gopublic.dk/cpr/media/12066/personnummeret-i-cpr.pdf>;
#' *Opbygning af CPR-nummeret*,
#' <https://www.cpr.dk/cpr-systemet/opbygning-af-cpr-nummeret>;
#' *Personnumre uden kontrolciffer (modulus 11 kontrol)*,
#' <https://www.cpr.dk/cpr-systemet/personnumre-uden-kontrolciffer-modulus-11-kontrol>.
#'
#' @examples
#' df <- data.frame(
#'   pnr = c("1111111118", "111111-1118", "111111118"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Default: add all columns
#' add_cpr_info(df, pnr)
#'
#' # Custom column names:
#' add_cpr_info(df, pnr, add = c(birth_date = "bday", years_old = "age"))
#'
#' # Unnamed: uses type names directly
#' add_cpr_info(df, pnr, add = c("bday", "sex"))
#'
#' @seealso [daos::clean_cpr()]
#'
#' @importFrom cli cli_abort
#' @importFrom rlang as_name enquo
#' @importFrom dplyr bind_cols
#' @importFrom tibble as_tibble
#' @export
add_cpr_info <- function(
    data,
    cpr_col,
    add      = c("bday", "age", "sex", "mod11", "valid"),
    ref_date = Sys.Date()
) {

  gyldige_typer <- c("bday", "age", "sex", "mod11", "valid")

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

  # Separator stripping and Excel-leading-zero repair live in clean_cpr(),
  # so the cleaning rule is defined in exactly one place.
  cpr_clean <- clean_cpr(data[[cpr_navn]])

  format_ok <- grepl("^\\d{10}$", cpr_clean, perl = TRUE)

  # The single string-to-number conversion. A 10-digit value is < 2^53, so
  # it is exactly representable in a double and all integer arithmetic on
  # it is exact. Invalid rows become NA here and propagate through every
  # computation below for free.
  num <- rep(NA_real_, length(cpr_clean))
  num[format_ok] <- as.numeric(cpr_clean[format_ok])

  # Peel the digits into an n-by-10 matrix: D[, k] is digit k of every CPR.
  D <- outer(num, 10^(9:0), function(n, p) (n %/% p) %% 10)

  dag    <- D[, 1L] * 10 + D[, 2L]
  maaned <- D[, 3L] * 10 + D[, 4L]
  aar2   <- D[, 5L] * 10 + D[, 6L]
  d7     <- D[, 7L]

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
  dage <- .cpr_days_from_civil(aar, maaned, dag)
  dage[!gyldig] <- NA_real_
  foedselsdato <- structure(as.double(dage), class = "Date")

  koen <- as.integer(D[, 10L] %% 2)

  # The mod-11 checksum for all rows at once: digit matrix times weight
  # vector is one BLAS call.
  m11_vaegte <- c(4, 3, 2, 7, 6, 5, 4, 3, 2, 1)
  m11_ok     <- as.vector(D %*% m11_vaegte) %% 11 == 0

  # Age via integer comparison of (month, day) pairs -- no formatting of
  # the date vector.
  ref      <- as.POSIXlt(ref_date)
  ref_md   <- (ref$mon + 1L) * 100L + ref$mday
  alder    <- as.integer(ref$year + 1900L - aar - (ref_md < maaned * 100 + dag))

  koen[!gyldig]  <- NA_integer_
  alder[!gyldig] <- NA_integer_

  alle <- list(
    bday  = foedselsdato,
    age   = alder,
    sex   = koen,
    mod11 = m11_ok,
    valid = gyldig
  )

  data[[cpr_navn]] <- cpr_clean

  valgt <- alle[unname(add)]
  names(valgt) <- names(add)

  dplyr::bind_cols(data, tibble::as_tibble(valgt))
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
