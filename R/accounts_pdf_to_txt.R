#' Convert PDF files to text files
#'
#' Reads all PDF files in a directory, extracts their text content using
#' [`pdftools::pdf_text()`], and writes one `.txt` file per PDF to the output
#' directory.
#'
#' @param pdf_dir Path to the directory containing PDF files.
#' @param txt_dir Path to the directory where text files will be written.
#'   Created automatically if it does not exist.
#'
#' @return Invisibly, a character vector of paths to the written `.txt` files.
#'
#' @examples
#' \dontrun{
#' accounts_pdf_to_txt("data/pdf", "data/txt")
#' }
#'
#' @importFrom cli cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @export
accounts_pdf_to_txt <- function(pdf_dir, txt_dir) {
  if (!requireNamespace("pdftools", quietly = TRUE))
    cli::cli_abort("Package {.pkg pdftools} is required to use {.fn accounts_pdf_to_txt}.")

  dir.create(txt_dir, recursive = TRUE, showWarnings = FALSE)

  pdf_files <- list.files(pdf_dir, pattern = "\\.pdf$", full.names = TRUE)
  if (length(pdf_files) == 0)
    cli::cli_abort("No PDF files found in {.path {pdf_dir}}.")

  pdf_files <- stats::setNames(pdf_files, tools::file_path_sans_ext(basename(pdf_files)))

  out_paths <- file.path(txt_dir, paste0(names(pdf_files), ".txt"))

  cli::cli_progress_bar("Converting PDFs", total = length(pdf_files))
  for (i in seq_along(pdf_files)) {
    cli::cli_progress_update(status = basename(pdf_files[[i]]))
    txt <- pdftools::pdf_text(pdf_files[[i]]) |> paste(collapse = "\n")
    cat(txt, file = out_paths[[i]])
  }
  cli::cli_progress_done()

  invisible(out_paths)
}
