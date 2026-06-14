#' Read one or more files
#'
#' Expands paths using [`glue::glue()`] (so `{0:9}` generates ten paths),
#' checks that every file exists, reads them with automatic format detection
#' or a custom reader, and optionally row-binds or unpacks the result.
#'
#' @details
#' **Supported formats (when `reader = "auto"`):**
#'
#' **Note on CSV:** uses `readr::read_csv2()` which expects semicolon-separated
#' values and a comma as the decimal mark (Danish/European convention). For
#' comma-separated files, pass a custom reader: `reader = readr::read_csv`.
#'
#' **Note on Excel:** only the first sheet is read. If a workbook has several
#' and you did not name one, a warning lists the others. Read a specific sheet
#' by forwarding the argument: `read_files("x.xlsx", sheet = "Sheet2")`.
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
#' @param paths A character vector of file paths. Glue syntax (`{}`) is
#'   supported for compact range expansion.
#' @param names Optional names for the result. Defaults to file names without
#'   extension. If numeric, the `.id` column (when `out = "bind"`) will also be
#'   numeric.
#' @param reader `"auto"` (default) to detect the format from the file
#'   extension, or a function `\(path, ...) ...` to use a custom reader.
#' @param out Controls what is returned after reading:
#'   - `NULL` (default): the object directly for a single file; a named list
#'     for multiple files.
#'   - `"bind"`: row-bind all data frames into a single tibble. If column
#'     types differ, a warning is issued and types are reconciled with
#'     [`readr::type_convert()`]. A source column is added when `.id` is set.
#'   - `"unpack"`: assign each element as a named variable in `.envir`.
#' @param .envir Environment used for glue interpolation and (when
#'   `out = "unpack"`) the target for assignment. Default is the calling frame.
#' @param .id Name of a source column added when `out = "bind"`. If `NULL`
#'   (default), no source column is added.
#' @param .overwrite If `FALSE` (default), aborts when any name already exists
#'   in `.envir` and `out = "unpack"`. Set to `TRUE` to allow overwrites.
#' @param .lowercase If `TRUE` (default), column names are converted to
#'   lowercase after reading. Set to `FALSE` to preserve original casing.
#' @param ... Additional arguments forwarded to the reader function.
#'
#' @return Depends on `out`:
#'   - `NULL`: the object (single file) or a named list (multiple files).
#'   - `"bind"`: a single tibble.
#'   - `"unpack"`: the named list, invisibly.
#'
#' @examples
#' \dontrun{
#' # Single file (returns object directly):
#' df <- read_files("data/results.parquet")
#'
#' # Multiple files with glue expansion:
#' lst <- read_files("data/dat{0:9}.parquet", names = 0:9)
#'
#' # Custom reader:
#' lst <- read_files(
#'   "data/dat{0:9}.parquet",
#'   reader = \(x) arrow::read_parquet(x, col_select = 1:5)
#' )
#'
#' # Read and bind into one tibble:
#' df <- read_files("data/dat{0:9}.parquet", names = 0:9, out = "bind")
#'
#' # Read and unpack into individual variables (dat0, dat1, ...):
#' read_files("data/dat{0:9}.parquet", names = paste0("dat", 0:9), out = "unpack")
#' summon("^dat\\d+$")
#' }
#'
#' @seealso [daos::summon()], [daos::view_types()]
#'
#' @importFrom glue glue
#' @importFrom cli cli_abort cli_warn cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom stats setNames
#' @importFrom dplyr mutate across everything bind_rows
#' @importFrom readr type_convert
#' @export
read_files <- function(paths, names = NULL, reader = "auto", out = NULL,
                       .envir = parent.frame(), .id = NULL, .overwrite = FALSE,
                       .lowercase = TRUE, ...) {

  if (!is.null(out) && !out %in% c("bind", "unpack")) {
    cli::cli_abort('{.arg out} must be {.val NULL}, {.val "bind"}, or {.val "unpack"}.')
  }

  if (!identical(reader, "auto") && !is.function(reader)) {
    cli::cli_abort('{.arg reader} must be {.val "auto"} or a function.')
  }

  # Expand paths (glue each element individually to support named vectors)
  input_names <- base::names(paths)
  files <- unlist(lapply(unname(paths), function(p) {
    as.character(glue::glue(p, .envir = .envir))
  }))

  missing_files <- files[!file.exists(files)]
  if (length(missing_files) > 0) {
    cli::cli_abort(c(
      "{length(missing_files)} of {length(files)} file{?s} could not be found.",
      stats::setNames(basename(missing_files), rep("x", length(missing_files)))
    ))
  }

  # Resolve names: explicit > input vector names > filenames
  id_type <- if (!is.null(names) && is.numeric(names)) "numeric" else "character"
  file_names <- if (!is.null(names)) {
    as.character(names)
  } else if (!is.null(input_names) && length(input_names) == length(files)) {
    input_names
  } else {
    tools::file_path_sans_ext(basename(files))
  }

  if (length(file_names) != length(files)) {
    cli::cli_abort("{.arg names} must have the same length as the number of files.")
  }

  files <- stats::setNames(files, file_names)

  # Build reader
  read_one <- if (identical(reader, "auto")) {
    function(path) .read_files_auto(path)(path, ...)
  } else {
    function(path) reader(path, ...)
  }
  maybe_lower <- if (.lowercase) {
    function(x) { if (is.data.frame(x)) base::names(x) <- tolower(base::names(x)); x }
  } else {
    identity
  }

  # Read into named list
  if (length(files) == 1) {
    result <- stats::setNames(list(maybe_lower(read_one(files[[1]]))), base::names(files))
  } else {
    result <- vector("list", length(files))
    base::names(result) <- base::names(files)
    cli::cli_progress_bar("Reading files", total = length(files))
    for (i in seq_along(files)) {
      cli::cli_progress_update(status = basename(files[[i]]))
      result[[i]] <- maybe_lower(read_one(files[[i]]))
    }
    cli::cli_progress_done()
  }

  # Apply out
  if (is.null(out)) {
    if (length(result) == 1) return(result[[1]])
    return(result)
  }

  if (out == "bind") {
    coerce_id <- function(df) {
      if (!is.null(.id) && id_type == "numeric") df[[.id]] <- as.numeric(df[[.id]])
      df
    }
    bound <- tryCatch(dplyr::bind_rows(result, .id = .id), error = function(e) e)
    if (!inherits(bound, "error")) return(coerce_id(bound))
    cli::cli_warn(c(
      "Column types differ across files -- coercing to character and re-typing with {.fun readr::type_convert}.",
      "i" = "Use {.fun daos::view_types} to inspect the differences."
    ))
    id_col_spec <- if (!is.null(.id)) {
      do.call(readr::cols, stats::setNames(list(readr::col_character()), .id))
    } else {
      readr::cols()
    }
    return(
      lapply(result, \(d) dplyr::mutate(d, dplyr::across(dplyr::everything(), as.character))) |>
        dplyr::bind_rows(.id = .id) |>
        readr::type_convert(col_types = id_col_spec) |>
        coerce_id()
    )
  }

  if (out == "unpack") {
    if (!.overwrite) {
      existing <- intersect(base::names(result), ls(envir = .envir))
      if (length(existing) > 0) {
        cli::cli_abort(c(
          "{length(existing)} object{?s} already exist{?s/} in target environment.",
          "x" = "Conflicts: {.val {existing}}.",
          "i" = "Set {.code .overwrite = TRUE} to replace them."
        ))
      }
    }
    list2env(result, envir = .envir)
    return(invisible(result))
  }
}

# read_xlsx()/read_xls() silently read only the first sheet. When a workbook
# has several and the caller did not name one, warn -- so a partial read is
# never a surprise -- and point at how to pick another. Reading itself is
# unchanged.
.read_excel <- function(path, read_fn, ...) {
  if (is.null(list(...)$sheet)) {
    sheets <- tryCatch(readxl::excel_sheets(path), error = function(e) character())
    if (length(sheets) > 1)
      cli::cli_warn(c(
        "{.file {basename(path)}} has {length(sheets)} sheets -- read only the first ({.val {sheets[1]}}).",
        "i" = "Other sheets: {.val {sheets[-1]}}.",
        "i" = 'Read another with {.code reader = \\(x) readxl::read_excel(x, sheet = "...")}.'
      ))
  }
  read_fn(path, ...)
}

.read_files_readers <- function() {
  list(
    csv      = readr::read_csv2,
    tsv      = readr::read_tsv,
    parquet  = function(...) {
      if (!requireNamespace("arrow", quietly = TRUE))
        cli::cli_abort("Package {.pkg arrow} is required to read parquet files.")
      arrow::read_parquet(...)
    },
    xlsx     = function(path, ...) {
      if (!requireNamespace("readxl", quietly = TRUE))
        cli::cli_abort("Package {.pkg readxl} is required to read xlsx files.")
      .read_excel(path, readxl::read_xlsx, ...)
    },
    xls      = function(path, ...) {
      if (!requireNamespace("readxl", quietly = TRUE))
        cli::cli_abort("Package {.pkg readxl} is required to read xls files.")
      .read_excel(path, readxl::read_xls, ...)
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
}

# Supported extensions, so callers (e.g. browse_files) can test whether a
# file is readable without invoking a reader.
.read_files_exts <- function() base::names(.read_files_readers())

.read_files_auto <- function(path) {
  readers <- .read_files_readers()
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% base::names(readers)) {
    cli::cli_abort(c(
      "No reader for {.field .{ext}} files.",
      "i" = "Supported: {.field {base::names(readers)}}.",
      "i" = "Use {.arg reader} to supply a custom reader function."
    ))
  }
  readers[[ext]]
}
