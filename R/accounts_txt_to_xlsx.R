#' Parse formatted text files and export to Excel
#'
#' Reads all `.txt` files in a directory, parses them according to a specific
#' layout used for manually formatted financial statements, and exports the
#' result as an Excel file. Messages report how many files were collected and
#' a summary when done. Files are validated one company at a time, so a
#' formatting problem aborts at the offending company with a message naming
#' the CVR, the file, and the offending lines or elements.
#'
#' @details
#' **Text file format:**
#'
#' Each line is either a *category line* or a *data line*:
#'
#' - **Category line:** a single string with no field delimiter. Becomes the
#'   `note` column for all subsequent data lines.
#' - **Data line:** three fields separated by `min_spaces` or more consecutive
#'   spaces: (1) element name, (2) amount for `year`, (3) amount for `year - 1`.
#'
#' Amounts must be in whole kroner (periods as thousands separators are stripped
#' automatically). If the previous year is absent, the third field may be empty
#' -- it becomes `NA`.
#'
#' Appending ` statnatio` to a category line negates all values in that
#' category (useful when costs appear with a positive sign in notes).
#'
#' File names are used as identifiers in the `cvr` column. A trailing `_spec`
#' suffix is stripped automatically (e.g. `12345678_spec.txt` -> `12345678`).
#'
#' @param txt_dir Path to the directory containing `.txt` files.
#' @param out_file Path to the output `.xlsx` file.
#' @param year The accounting year as a numeric scalar (e.g. `2024`).
#' @param min_spaces Minimum number of consecutive spaces used as field
#'   delimiter. Default `3`.
#'
#' @return The parsed data as a tibble, invisibly.
#'
#' @examples
#' \dontrun{
#' accounts_txt_to_xlsx("data/txt", "data/output.xlsx", year = 2024)
#' }
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom readr read_lines
#' @importFrom dplyr mutate filter if_else bind_rows
#' @importFrom tibble as_tibble tibble
#' @export
accounts_txt_to_xlsx <- function(txt_dir, out_file, year, min_spaces = 3) {
  if (!requireNamespace("writexl", quietly = TRUE))
    cli::cli_abort("Package {.pkg writexl} is required to use {.fn accounts_txt_to_xlsx}.")

  year_val <- year
  delim    <- paste0(" {", min_spaces, ",}")

  txt_files <- list.files(txt_dir, pattern = "\\.txt$", full.names = TRUE)
  if (length(txt_files) == 0)
    cli::cli_abort("No txt files found in {.path {txt_dir}}.")

  txt_files <- stats::setNames(
    txt_files,
    sub("_spec$", "", tools::file_path_sans_ext(basename(txt_files)))
  )

  n <- length(txt_files)
  cli::cli_alert_info("Collected {n} txt file{?s} from {.path {txt_dir}}, parsing and validating...")
  t0 <- Sys.time()

  # Read raw
  raw <- lapply(txt_files, \(f) {
    readr::read_lines(f) |>
      .split3(pattern = delim) |>
      tibble::as_tibble()
  })

  # Parse and validate per company; abort at the first company with problems
  parsed <- vector("list", n)
  names(parsed) <- names(raw)
  cli::cli_progress_bar("Parsing companies", total = n)
  for (i in seq_along(raw)) {
    cvr <- names(raw)[[i]]
    cli::cli_progress_update(status = cvr)
    d <- raw[[i]]

    # Validate: no commas in value columns (row index == line number in file)
    bad_lines <- which(grepl(",", d$V2, fixed = TRUE) | grepl(",", d$V3, fixed = TRUE))
    if (length(bad_lines) > 0)
      cli::cli_abort(c(
        "[{i}/{n}] {cvr}: comma detected in value columns.",
        "x" = "{cli::qty(length(bad_lines))}Line{?s} {bad_lines} of {.path {txt_files[[i]]}}.",
        "i" = "Amounts must be whole kroner with periods as thousands separators."
      ))

    d <- dplyr::mutate(d, note = dplyr::if_else(V2 == "", V1, NA_character_), .before = 1)
    d <- dplyr::mutate(d, note = .fill_down(note))
    d <- dplyr::filter(d, V2 != "")

    # Long format: two rows per element (current year first, then last year)
    long <- tibble::tibble(
      note      = rep(d$note, each = 2),
      elementid = rep(d$V1, each = 2),
      year      = rep(c(year_val, year_val - 1), times = nrow(d)),
      val       = c(rbind(d$V2, d$V3))  # interleave V2/V3 per element
    )

    out <- dplyr::mutate(
      long,
      val  = suppressWarnings(as.numeric(gsub(".", "", val, fixed = TRUE))) / 1e3,
      note = trimws(note),
      val  = dplyr::if_else(grepl("statnatio$", note), -val, val),
      note = tolower(sub(" statnatio$", "", note)),
      elementid = tolower(elementid)
    )

    # Validate: no NAs in note or elementid
    bad_note <- unique(out$elementid[is.na(out$note) | is.na(out$elementid)])
    if (length(bad_note) > 0)
      cli::cli_abort(c(
        "[{i}/{n}] {cvr}: NA in note or elementid.",
        "x" = "{cli::qty(length(bad_note))}Element{?s} {.val {bad_note}} in {.path {txt_files[[i]]}}.",
        "i" = "Data lines before the first category line have no note."
      ))

    # Validate: no NAs in current year values
    bad_val <- unique(out$elementid[is.na(out$val) & out$year == year_val])
    if (length(bad_val) > 0)
      cli::cli_abort(c(
        "[{i}/{n}] {cvr}: non-numeric values in current year ({year_val}).",
        "x" = "{cli::qty(length(bad_val))}Element{?s} {.val {bad_val}} in {.path {txt_files[[i]]}}."
      ))

    parsed[[i]] <- out
  }
  cli::cli_progress_done()
  data <- dplyr::bind_rows(parsed, .id = "cvr")

  writexl::write_xlsx(data, out_file)
  cli::cli_alert_success(
    "Wrote {nrow(data)} row{?s} for {n} compan{?y/ies} to {.path {out_file}} in {format_elapsed(Sys.time() - t0)}."
  )

  invisible(data)
}
