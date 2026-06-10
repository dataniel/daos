#' Parse formatted text files and export to Excel
#'
#' Reads all `.txt` files in a directory, parses them according to a specific
#' layout used for manually formatted financial statements, and exports the
#' result as an Excel file. Messages report how many files were collected and
#' a summary when done. All companies are validated before any output is
#' written; formatting problems abort with a combined message listing every
#' offending company along with the file and the offending lines or elements.
#' Files containing no data lines at all are skipped with a warning message;
#' if no file yields any data the function aborts.
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
#' @param overwrite If `FALSE` (default), the function aborts when `out_file`
#'   already exists. Set to `TRUE` to replace it.
#'
#' @return The parsed data as a tibble, invisibly.
#'
#' @examples
#' \dontrun{
#' accounts_txt_to_xlsx("data/txt", "data/output.xlsx", year = 2024)
#' }
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_alert_warning cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom readr read_lines
#' @importFrom dplyr mutate filter if_else bind_rows
#' @importFrom tibble as_tibble tibble
#' @export
accounts_txt_to_xlsx <- function(txt_dir, out_file, year, min_spaces = 3, overwrite = FALSE) {
  if (!requireNamespace("writexl", quietly = TRUE))
    cli::cli_abort("Package {.pkg writexl} is required to use {.fn accounts_txt_to_xlsx}.")

  if (!overwrite && file.exists(out_file))
    cli::cli_abort(c(
      "Would overwrite existing output file {.path {out_file}}.",
      "i" = "Set {.code overwrite = TRUE} to replace it."
    ))

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
  txt_dir_lnk <- .path_link(txt_dir)
  cli::cli_alert_info("Collected {n} txt file{?s} from '{txt_dir_lnk}', parsing and validating...")
  t0 <- Sys.time()

  # Read raw
  raw <- lapply(txt_files, \(f) {
    readr::read_lines(f) |>
      .split3(pattern = delim) |>
      tibble::as_tibble()
  })

  # Parse and validate all companies, collecting problems for a combined report
  parsed <- vector("list", n)
  names(parsed) <- names(raw)
  issues <- character()
  issue_cvrs <- character()
  cli::cli_progress_bar("Parsing companies", total = n)
  for (i in seq_along(raw)) {
    cvr <- names(raw)[[i]]
    cli::cli_progress_update(status = cvr)
    d <- raw[[i]]
    file_lnk <- .path_link(txt_files[[i]], basename(txt_files[[i]]))

    # Validate: no commas in value columns (row index == line number in file)
    bad_lines <- which(grepl(",", d$V2, fixed = TRUE) | grepl(",", d$V3, fixed = TRUE))
    if (length(bad_lines) > 0) {
      issues <- c(issues, cli::format_inline(
        "{cvr}: comma in value columns ({cli::qty(length(bad_lines))}line{?s} {bad_lines} in {file_lnk})"
      ))
      issue_cvrs <- c(issue_cvrs, cvr)
      next  # comma values cannot be parsed; skip to avoid derived NA noise
    }

    d <- dplyr::mutate(d, note = dplyr::if_else(V2 == "", V1, NA_character_), .before = 1)
    d <- dplyr::mutate(d, note = .fill_down(note))
    d <- dplyr::filter(d, V2 != "")

    if (nrow(d) == 0) {
      cli::cli_alert_warning(
        "{cvr}: no data lines found in {file_lnk} (check the format or {.arg min_spaces}) -- skipped."
      )
      next
    }

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
    if (length(bad_note) > 0) {
      issues <- c(issues, cli::format_inline(
        "{cvr}: NA in note or elementid ({cli::qty(length(bad_note))}element{?s} {.val {bad_note}} in {file_lnk})"
      ))
      issue_cvrs <- c(issue_cvrs, cvr)
    }

    # Validate: no NAs in current year values
    bad_val <- unique(out$elementid[is.na(out$val) & out$year == year_val])
    if (length(bad_val) > 0) {
      issues <- c(issues, cli::format_inline(
        "{cvr}: non-numeric value in current year ({cli::qty(length(bad_val))}element{?s} {.val {bad_val}} in {file_lnk})"
      ))
      issue_cvrs <- c(issue_cvrs, cvr)
    }

    parsed[[i]] <- out
  }
  cli::cli_progress_done()

  if (length(issues) > 0) {
    shown <- stats::setNames(utils::head(issues, 10), rep("x", min(length(issues), 10)))
    if (length(issues) > 10)
      shown <- c(shown, cli::format_inline("... and {length(issues) - 10} more issue{?s}."))
    cli::cli_abort(c(
      "Validation failed for {length(unique(issue_cvrs))} of {n} companies:",
      shown,
      "i" = "Fix the files above and rerun. Nothing was written to '{out_file}'."
    ))
  }

  data <- dplyr::bind_rows(parsed, .id = "cvr")
  if (nrow(data) == 0)
    cli::cli_abort("No data lines found in any txt file -- nothing to write.")

  writexl::write_xlsx(data, out_file)
  out_file_lnk <- .path_link(out_file)
  cli::cli_alert_success(
    "Wrote {nrow(data)} row{?s} for {n} compan{?y/ies} to '{out_file_lnk}' in {format_elapsed(Sys.time() - t0)}."
  )

  invisible(data)
}
