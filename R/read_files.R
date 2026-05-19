#' Read one or more files with automatic format detection
#'
#' Detects the file format from the extension and dispatches to the
#' appropriate reader. Supports a wide range of tabular, statistical, and
#' structured formats. When multiple paths are supplied, a named list is
#' returned and a progress bar is shown.
#'
#' @details
#' **Supported formats:**
#'
#' **Note on CSV:** `read_files()` uses `readr::read_csv2()` for `.csv` files,
#' which expects **semicolon-separated** values and a comma as the decimal mark
#' (the Danish/European convention). If your CSV uses commas as separators,
#' pass the file directly to `readr::read_csv()` instead.
#'
#' | Extension | Reader |
#' |-----------|--------|
#' | `csv` | `readr::read_csv2()` (semicolon-separated, European format) |
#' | `tsv` | `readr::read_tsv()` |
#' | `parquet`, `feather` | `arrow::read_parquet()` / `arrow::read_feather()` |
#' | `xlsx`, `xls` | `readxl::read_xlsx()` / `readxl::read_xls()` |
#' | `rds` | `readRDS()` |
#' | `sas7bdat`, `sav`, `por`, `xpt`, `dta` | `haven::read_*()` |
#' | `json`, `ndjson`, `jsonl` | `jsonlite::read_json()` / `jsonlite::stream_in()` |
#' | `yaml`, `yml` | `yaml::read_yaml()` |
#' | `txt` | `readr::read_lines()` |
#'
#' Packages for non-base formats (`arrow`, `haven`, `readxl`, `jsonlite`,
#' `yaml`) must be installed separately.
#'
#' @param paths A single file path or a character vector of file paths. If
#'   the vector is unnamed, file names (without extension) are used as list
#'   names.
#' @param ... Additional arguments forwarded to the underlying reader.
#'
#' @return For a single path: the object returned by the reader. For multiple
#'   paths: a named list of objects.
#'
#' @examples
#' \dontrun{
#' # Single file
#' df <- read_files("data/results.parquet")
#'
#' # Multiple files — returns a named list
#' files <- read_files(c("data/a.csv", "data/b.csv"))
#'
#' # Pipeline with require_files() and bind_files():
#' require_files("data/dat{0:9}.parquet") |>
#'   read_files() |>
#'   bind_files()
#' }
#'
#' @seealso [daos::require_files()], [daos::bind_files()], [daos::unpack_files()]
#'
#' @importFrom cli cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom fs path_ext path_file path_ext_remove
#' @export
read_files <- function(paths, ...) {

  readers <- list(
    csv      = readr::read_csv2,
    tsv      = readr::read_tsv,
    parquet  = function(...) {
      if (!requireNamespace("arrow", quietly = TRUE))
        cli::cli_abort("Package {.pkg arrow} is required to read parquet files.")
      arrow::read_parquet(...)
    },
    xlsx     = function(...) {
      if (!requireNamespace("readxl", quietly = TRUE))
        cli::cli_abort("Package {.pkg readxl} is required to read xlsx files.")
      readxl::read_xlsx(...)
    },
    xls      = function(...) {
      if (!requireNamespace("readxl", quietly = TRUE))
        cli::cli_abort("Package {.pkg readxl} is required to read xls files.")
      readxl::read_xls(...)
    },
    feather  = function(...) {
      if (!requireNamespace("arrow", quietly = TRUE))
        cli::cli_abort("Package {.pkg arrow} is required to read feather files.")
      arrow::read_feather(...)
    },
    rds      = readRDS,
    sas7bdat = function(...) {
      if (!requireNamespace("haven", quietly = TRUE))
        cli::cli_abort("Package {.pkg haven} is required to read SAS files.")
      haven::read_sas(...)
    },
    sav      = function(...) {
      if (!requireNamespace("haven", quietly = TRUE))
        cli::cli_abort("Package {.pkg haven} is required to read SPSS files.")
      haven::read_sav(...)
    },
    por      = function(...) {
      if (!requireNamespace("haven", quietly = TRUE))
        cli::cli_abort("Package {.pkg haven} is required to read SPSS portable files.")
      haven::read_por(...)
    },
    xpt      = function(...) {
      if (!requireNamespace("haven", quietly = TRUE))
        cli::cli_abort("Package {.pkg haven} is required to read SAS transport files.")
      haven::read_xpt(...)
    },
    dta      = function(...) {
      if (!requireNamespace("haven", quietly = TRUE))
        cli::cli_abort("Package {.pkg haven} is required to read Stata files.")
      haven::read_dta(...)
    },
    json     = function(...) {
      if (!requireNamespace("jsonlite", quietly = TRUE))
        cli::cli_abort("Package {.pkg jsonlite} is required to read JSON files.")
      jsonlite::read_json(...)
    },
    ndjson   = function(...) {
      if (!requireNamespace("jsonlite", quietly = TRUE))
        cli::cli_abort("Package {.pkg jsonlite} is required to read NDJSON files.")
      jsonlite::stream_in(...)
    },
    jsonl    = function(...) {
      if (!requireNamespace("jsonlite", quietly = TRUE))
        cli::cli_abort("Package {.pkg jsonlite} is required to read JSONL files.")
      jsonlite::stream_in(...)
    },
    yaml     = function(...) {
      if (!requireNamespace("yaml", quietly = TRUE))
        cli::cli_abort("Package {.pkg yaml} is required to read YAML files.")
      yaml::read_yaml(...)
    },
    yml      = function(...) {
      if (!requireNamespace("yaml", quietly = TRUE))
        cli::cli_abort("Package {.pkg yaml} is required to read YAML files.")
      yaml::read_yaml(...)
    },
    txt      = readr::read_lines
  )

  auto_reader <- function(path) {
    ext <- tolower(fs::path_ext(path))
    if (!ext %in% names(readers)) {
      cli::cli_abort(c(
        "No reader for {.field .{ext}} files.",
        "i" = "Supported: {.field {names(readers)}}.",
        "i" = "Use a specific reader function for other formats."
      ))
    }
    readers[[ext]]
  }

  if (length(paths) == 1) {
    return(auto_reader(paths)(paths, ...))
  }

  if (is.null(names(paths))) {
    names(paths) <- fs::path_file(paths) |> fs::path_ext_remove()
  }

  out <- vector("list", length(paths))
  names(out) <- names(paths)

  cli::cli_progress_bar("Reading files", total = length(paths))
  for (i in seq_along(paths)) {
    cli::cli_progress_update(status = fs::path_file(paths[[i]]))
    out[[i]] <- auto_reader(paths[[i]])(paths[[i]], ...)
  }
  cli::cli_progress_done()

  out
}
