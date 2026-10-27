#' Read a Greenlandic TA file in the new layout
#'
#' Reads a Greenlandic TA file in the new 140-character layout, the one
#' [write_ta2()] writes. For the old layout, use [read_ta()].
#'
#' @details
#' Both layouts are kept during the transition to the new TA system, and
#' afterwards so old files can still be read. The `2` marks the new layout,
#' not a newer version of the same function. An old-layout file is shorter
#' than 140 characters per line and is therefore rejected rather than read
#' into the wrong columns.
#'
#' Column positions (1-based characters):
#'
#' | Column  | Positions |
#' |---------|-----------|
#' | nrnr    | 1--6      |
#' | trans   | 17--21    |
#' | brch    | 31--35    |
#' | bas     | 36--60    |
#' | eng     | 61--76    |
#' | det     | 77--92    |
#' | afg     | 93--108   |
#' | moms    | 109--124  |
#' | kbx     | 125--140  |
#'
#' Fields are trimmed, and blank fields are read as `NA`. Columns `nrnr`,
#' `trans`, and `brch` are read as character; the rest as double. A numeric
#' field that is not a number is an error, not a silent `NA`.
#'
#' @param path Path to the TA file.
#'
#' @return A tibble with the nine columns above.
#'
#' @examples
#' \dontrun{
#' df <- read_ta2("ta.file")
#' }
#'
#' @export
read_ta2 <- function(path) {
  lines <- readLines(path, warn = FALSE)

  short <- which(nchar(lines) < 140)
  if (length(short) > 0) {
    cli::cli_abort(c(
      "{cli::qty(length(short))}Line{?s} {short} {cli::qty(length(short))}{?is/are} shorter than the 140 characters of the TA layout.",
      i = "Is this an old-layout file? Use {.fn read_ta} for those."
    ))
  }

  pos <- list(nrnr = c(1, 6), trans = c(17, 21), brch = c(31, 35),
              bas = c(36, 60), eng = c(61, 76), det = c(77, 92),
              afg = c(93, 108), moms = c(109, 124), kbx = c(125, 140))
  num_cols <- c("bas", "eng", "det", "afg", "moms", "kbx")

  out <- lapply(pos, function(p) {
    v <- trimws(substr(lines, p[1], p[2]))
    v[v == ""] <- NA_character_
    v
  })

  raw <- out[num_cols]
  out[num_cols] <- lapply(raw, function(v) suppressWarnings(as.numeric(v)))

  problems <- unlist(lapply(num_cols, function(col) {
    rows <- which(!is.na(raw[[col]]) & is.na(out[[col]]))
    sprintf('%s, line %d: "%s" is not a number.', col, rows, raw[[col]][rows])
  }))
  if (length(problems) > 0) {
    cli::cli_abort(c(
      "Cannot read {length(problems)} numeric field{?s}:",
      cap_bullets(problems)
    ))
  }

  tibble::as_tibble(out)
}
