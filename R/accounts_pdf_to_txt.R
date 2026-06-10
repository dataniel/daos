#' Convert PDF files to text files
#'
#' Reads all PDF files in a directory, extracts their text content using
#' [`pdftools::pdf_text()`], and writes one `.txt` file per PDF to the output
#' directory. A progress bar is shown while converting; messages are only
#' emitted for skipped PDFs, plus a summary when done.
#'
#' PDFs with no extractable text (blank or whitespace only -- typically
#' scanned/photo-printed annual reports) are skipped with a warning message;
#' no `.txt` file is written for them.
#'
#' @param pdf_dir Path to the directory containing PDF files.
#' @param txt_dir Path to the directory where text files will be written.
#'   Created automatically if it does not exist.
#'
#' @return Invisibly, a character vector of paths to the written `.txt` files
#'   (skipped PDFs are not included).
#'
#' @examples
#' \dontrun{
#' accounts_pdf_to_txt("data/pdf", "data/txt")
#' }
#'
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_alert_warning cli_progress_bar cli_progress_update cli_progress_done
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

  n <- length(pdf_files)
  cli::cli_alert_info("Found {n} PDF file{?s} in {.path {pdf_dir}}.")

  t0 <- Sys.time()
  written <- logical(n)
  cli::cli_progress_bar("Converting PDFs", total = n)
  for (i in seq_along(pdf_files)) {
    cli::cli_progress_update(status = names(pdf_files)[[i]])
    pages <- pdftools::pdf_text(pdf_files[[i]])
    txt <- paste(pages, collapse = "\n")

    if (!nzchar(trimws(txt))) {
      cli::cli_alert_warning(
        "{names(pdf_files)[[i]]}: no extractable text (probably a scanned PDF) -- skipped."
      )
      next
    }

    cat(txt, file = out_paths[[i]])
    written[[i]] <- TRUE
  }
  cli::cli_progress_done()

  cli::cli_alert_success(
    "Wrote {sum(written)} text file{?s} to {.path {txt_dir}} in {format_elapsed(Sys.time() - t0)}."
  )

  invisible(out_paths[written])
}
