#' Parse formatted text files and export to Excel
#'
#' Reads all `.txt` files in a directory, parses them according to a specific
#' layout used for manually formatted financial statements, and exports the
#' result as an Excel file.
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
#' @importFrom cli cli_abort cli_progress_bar cli_progress_update cli_progress_done
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

  # Read raw
  cli::cli_progress_bar("Reading files", total = length(txt_files))
  raw <- vector("list", length(txt_files))
  names(raw) <- names(txt_files)
  for (i in seq_along(txt_files)) {
    cli::cli_progress_update(status = basename(txt_files[[i]]))
    raw[[i]] <- readr::read_lines(txt_files[[i]]) |>
      .split3(pattern = delim) |>
      tibble::as_tibble()
  }
  cli::cli_progress_done()

  # Validate: no commas in value columns
  lapply(raw, \(d) dplyr::filter(d, grepl(",", V2, fixed = TRUE) |
                                    grepl(",", V3, fixed = TRUE))) |>
    dplyr::bind_rows(.id = "cvr") |>
    expect_empty(abort_msg = "Comma detected in value columns -- check text file formatting.")

  # Parse
  data <- lapply(raw, function(d) {
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

    dplyr::mutate(
      long,
      val  = as.numeric(gsub(".", "", val, fixed = TRUE)) / 1e3,
      note = trimws(note),
      val  = dplyr::if_else(grepl("statnatio$", note), -val, val),
      note = tolower(sub(" statnatio$", "", note)),
      elementid = tolower(elementid)
    )
  }) |>
    dplyr::bind_rows(.id = "cvr")

  # Validate: no NAs in note or elementid
  dplyr::filter(data, is.na(note) | is.na(elementid)) |>
    expect_empty(abort_msg = "NA in note or elementid -- check text file formatting.")

  # Validate: no NAs in current year values
  dplyr::filter(data, is.na(val) & year == year_val) |>
    expect_empty(abort_msg = "NA values in current year -- check text file formatting.")

  writexl::write_xlsx(data, out_file)

  invisible(data)
}
