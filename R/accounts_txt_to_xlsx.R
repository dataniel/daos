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
#' @importFrom fs dir_ls path_file path_ext_remove
#' @importFrom purrr map list_rbind
#' @importFrom readr read_lines
#' @importFrom stringr str_split_fixed str_detect str_remove_all str_remove str_to_lower
#' @importFrom dplyr mutate filter rename if_else across
#' @importFrom tidyr fill pivot_longer
#' @importFrom tibble as_tibble
#' @export
accounts_txt_to_xlsx <- function(txt_dir, out_file, year, min_spaces = 3) {
  if (!requireNamespace("writexl", quietly = TRUE))
    cli::cli_abort("Package {.pkg writexl} is required to use {.fn accounts_txt_to_xlsx}.")

  year_val <- year
  yr       <- as.character(year)
  yr_lag   <- as.character(year - 1)
  delim    <- paste0(" {", min_spaces, ",}")

  txt_files <- fs::dir_ls(txt_dir, glob = "*.txt")
  if (length(txt_files) == 0)
    cli::cli_abort("No txt files found in {.path {txt_dir}}.")

  txt_files <- stats::setNames(
    txt_files,
    sub("_spec$", "", fs::path_ext_remove(fs::path_file(txt_files)))
  )

  # Read raw
  cli::cli_progress_bar("Reading files", total = length(txt_files))
  raw <- vector("list", length(txt_files))
  names(raw) <- names(txt_files)
  for (i in seq_along(txt_files)) {
    cli::cli_progress_update(status = fs::path_file(txt_files[[i]]))
    raw[[i]] <- readr::read_lines(txt_files[[i]]) |>
      stringr::str_split_fixed(pattern = delim, n = 3) |>
      tibble::as_tibble(.name_repair = ~ c("V1", "V2", "V3"))
  }
  cli::cli_progress_done()

  # Validate: no commas in value columns
  purrr::map(raw, ~ dplyr::filter(.x, stringr::str_detect(V2, ",") | stringr::str_detect(V3, ","))) |>
    purrr::list_rbind(names_to = "cvr") |>
    expect_empty(abort_msg = "Comma detected in value columns -- check text file formatting.")

  # Parse
  data <- purrr::map(raw, function(d) {
    d |>
      dplyr::mutate(note = dplyr::if_else(V2 == "", V1, NA_character_), .before = 1) |>
      tidyr::fill(note, .direction = "down") |>
      dplyr::filter(V2 != "") |>
      dplyr::rename(elementid = V1, !!yr := V2, !!yr_lag := V3) |>
      tidyr::pivot_longer(-c(note, elementid), names_to = "year", values_to = "val") |>
      dplyr::mutate(
        val  = as.numeric(stringr::str_remove_all(val, "\\.")) / 1e3,
        year = as.numeric(year),
        note = trimws(note),
        val  = dplyr::if_else(stringr::str_detect(note, "statnatio$"), -val, val),
        note = stringr::str_remove(note, " statnatio$")
      ) |>
      dplyr::mutate(dplyr::across(c(note, elementid), stringr::str_to_lower))
  }) |>
    purrr::list_rbind(names_to = "cvr")

  # Validate: no NAs in note or elementid
  dplyr::filter(data, is.na(note) | is.na(elementid)) |>
    expect_empty(abort_msg = "NA in note or elementid -- check text file formatting.")

  # Validate: no NAs in current year values
  dplyr::filter(data, is.na(val) & year == year_val) |>
    expect_empty(abort_msg = "NA values in current year -- check text file formatting.")

  writexl::write_xlsx(data, out_file)

  invisible(data)
}
