#' Read one or more files
#'
#' Expands paths using [`glue::glue()`] (so `{0:9}` generates ten paths),
#' checks that every file exists, reads them with automatic format detection
#' or a custom reader, and optionally row-binds or unpacks the result.
#'
#' @details
#' **Supported formats (when `reader = "auto"`):**
#'
#' | Extension | Reader |
#' |-----------|--------|
#' | `csv` | `readr::read_delim()` (semicolon-separated, decimal comma) |
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
#' **Note on CSV:** reads semicolon-separated values with a comma as the
#' decimal mark (Danish/European convention), the same rule as
#' `readr::read_csv2()`: a `locale` you pass keeps its other settings (such as
#' `encoding`) but gets the decimal comma unless it names its own decimal mark.
#' Unlike `read_csv2()`, it does not print the locale and the column
#' specification for every file; pass `show_col_types = TRUE` to see them. For
#' comma-separated files, pass a custom reader: `reader = readr::read_csv`.
#'
#' **Note on Excel:** only the first sheet is read. If workbooks have several
#' and you did not name one, a single warning lists the other sheets of each.
#' Read a specific sheet by forwarding the argument:
#' `read_files("x.xlsx", sheet = "Sheet2")`.
#'
#' **Problems are reported together, not one at a time.** Missing files and
#' unsupported extensions are checked before anything is read. A file that
#' fails to read does not stop the others: every failure is collected and
#' reported in one error at the end, naming each file, so a broken delivery
#' is diagnosed in one run instead of one rerun per file.
#'
#' @param paths A character vector of file paths. Glue syntax (`{}`) is
#'   supported for compact range expansion. Elements may be named, which
#'   names the result, as long as each named element expands to one file.
#' @param names Optional names for the result. Defaults to the names of
#'   `paths`, then to file names without extension. If numeric, the `.id`
#'   column (when `out = "bind"`) will also be numeric.
#' @param reader `"auto"` (default) to detect the format from the file
#'   extension, or a function `\(path, ...) ...` to use a custom reader.
#' @param out Controls what is returned after reading:
#'   - `NULL` (default): the object directly for a single file; a named list
#'     for multiple files.
#'   - `"bind"`: row-bind all data frames into a single tibble. Columns whose
#'     types cannot be combined across files are converted to character and
#'     re-typed with [`readr::parse_guess()`], with a warning naming them;
#'     every other column keeps the type it was read with. A source column is
#'     added when `.id` is set.
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
#' @importFrom dplyr bind_rows
#' @export
read_files <- function(paths, names = NULL, reader = "auto", out = NULL,
                       .envir = parent.frame(), .id = NULL, .overwrite = FALSE,
                       .lowercase = TRUE, ...) {

  if (!is.null(out) && !(length(out) == 1 && out %in% c("bind", "unpack"))) {
    cli::cli_abort('{.arg out} must be {.val NULL}, {.val "bind"}, or {.val "unpack"}.')
  }

  if (!identical(reader, "auto") && !is.function(reader)) {
    cli::cli_abort('{.arg reader} must be {.val "auto"} or a function.')
  }

  # Expand paths (glue each element individually so a name on an element can
  # be checked against the files it expands to)
  expanded <- lapply(unname(paths), function(p) {
    as.character(glue::glue(p, .envir = .envir))
  })
  files <- unlist(expanded)

  missing_files <- files[!file.exists(files)]
  if (length(missing_files) > 0) {
    cli::cli_abort(c(
      "{length(missing_files)} of {length(files)} file{?s} could not be found:",
      cap_bullets(missing_files)
    ))
  }

  if (identical(reader, "auto")) {
    readers <- .read_files_readers()
    exts <- tolower(tools::file_ext(files))
    unknown <- unique(exts[!exts %in% names(readers)])
    if (length(unknown) > 0) {
      cli::cli_abort(c(
        "No reader for {.field {paste0('.', unknown)}} files.",
        "i" = "Supported: {.field {names(readers)}}.",
        "i" = "Use {.arg reader} to supply a custom reader function."
      ))
    }
    read_one <- function(path) readers[[tolower(tools::file_ext(path))]](path, ...)
  } else {
    read_one <- function(path) reader(path, ...)
  }

  # Resolve names: explicit > input vector names > filenames
  id_type <- if (!is.null(names) && is.numeric(names)) "numeric" else "character"
  if (!is.null(names)) {
    if (length(names) != length(files)) {
      cli::cli_abort(c(
        "{.arg names} must have the same length as the number of files.",
        "x" = "{.arg names} has {length(names)} element{?s}; {.arg paths} expands to {length(files)} file{?s}."
      ))
    }
    file_names <- as.character(names)
  } else {
    file_names <- .read_files_names(expanded, base::names(paths))
  }

  dups <- unique(file_names[duplicated(file_names)])
  if (length(dups) > 0) {
    if (identical(out, "unpack")) {
      cli::cli_abort(c(
        "Several files would be unpacked to the same name: {.val {dups}}.",
        "i" = "Name them apart with {.arg names}."
      ))
    } else if (is.null(out) || !is.null(.id)) {
      cli::cli_warn(c(
        "Several files share the name {.val {dups}}, so they cannot be told apart in the result.",
        "i" = "Name them apart with {.arg names}."
      ))
    }
  }

  maybe_lower <- if (.lowercase) {
    function(x) { if (is.data.frame(x)) names(x) <- tolower(names(x)); x }
  } else {
    identity
  }

  # Read every file even if one fails, so all failures (and all multi-sheet
  # workbooks) are reported together after the loop
  result <- vector("list", length(files))
  names(result) <- file_names
  failed <- character()
  sheet_notes <- character()
  cli::cli_progress_bar("Reading files", total = length(files))
  for (i in seq_along(files)) {
    cli::cli_progress_update(status = basename(files[[i]]))
    result[i] <- list(tryCatch(
      withCallingHandlers(
        maybe_lower(read_one(files[[i]])),
        daos_excel_sheets = function(w) {
          sheet_notes[[files[[i]]]] <<- paste0('also "', paste(w$sheets[-1], collapse = '", "'), '"')
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        failed[[files[[i]]]] <<- sub("\n.*", "", conditionMessage(e))
        NULL
      }
    ))
  }
  cli::cli_progress_done()

  if (length(failed) > 0) {
    cli::cli_abort(c(
      "Could not read {length(failed)} of {length(files)} file{?s}:",
      cap_bullets(paste0(base::names(failed), ": ", failed))
    ))
  }

  if (length(sheet_notes) > 0) {
    cli::cli_warn(c(
      "{length(sheet_notes)} workbook{?s} {?has/have} more than one sheet; only the first was read.",
      cap_bullets(paste0(base::names(sheet_notes), ": ", sheet_notes), bullet = "*"),
      "i" = 'Read another sheet with {.code sheet = "..."}, which is passed on to the reader.'
    ))
  }

  # Apply out
  if (is.null(out)) {
    if (length(result) == 1) return(result[[1]])
    return(result)
  }

  if (out == "bind") {
    bound <- .read_files_bind(result, files, .id)
    if (!is.null(.id) && id_type == "numeric") bound[[.id]] <- as.numeric(bound[[.id]])
    return(bound)
  }

  if (out == "unpack") {
    if (!.overwrite) {
      existing <- intersect(names(result), ls(envir = .envir, all.names = TRUE))
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

# Default names: an element's own name when it expands to exactly one file,
# else the file names. A name on a pattern that expands to several files has
# no sensible meaning, so that is an error rather than a silent fallback.
.read_files_names <- function(expanded, input_names, call = rlang::caller_env()) {
  if (is.null(input_names)) input_names <- rep("", length(expanded))
  input_names[is.na(input_names)] <- ""
  multi <- input_names != "" & lengths(expanded) > 1
  if (any(multi)) {
    cli::cli_abort(c(
      "A name in {.arg paths} must belong to a single file.",
      "x" = "{.val {input_names[multi]}} expand{?s/} to several files.",
      "i" = "Name the files with {.arg names} instead."
    ), call = call)
  }
  unlist(Map(function(nm, f) {
    if (nm != "") rep(nm, length(f)) else tools::file_path_sans_ext(basename(f))
  }, input_names, expanded), use.names = FALSE)
}

# Row-bind the files. Columns whose types cannot be combined are found on
# zero-row slices (cheap: no data is copied), and only those are converted to
# character and re-guessed after the bind. Re-guessing every column would
# throw away types the files agree on, such as a column deliberately read as
# character.
.read_files_bind <- function(result, files, .id, call = rlang::caller_env()) {
  is_df <- vapply(result, is.data.frame, logical(1))
  if (!all(is_df)) {
    classes <- vapply(result[!is_df], function(x) class(x)[1], character(1))
    cli::cli_abort(c(
      '{.code out = "bind"} needs data frames, but {sum(!is_df)} file{?s} did not read as one:',
      cap_bullets(paste0(files[!is_df], ": <", classes, ">"))
    ), call = call)
  }

  protos <- lapply(result, function(d) d[0, , drop = FALSE])
  cols <- unique(unlist(lapply(protos, names)))
  conflicts <- cols[vapply(cols, function(col) {
    slices <- lapply(protos, function(p) p[intersect(col, names(p))])
    inherits(tryCatch(dplyr::bind_rows(slices), error = identity), "error")
  }, logical(1))]

  if (length(conflicts) == 0) return(dplyr::bind_rows(result, .id = .id))

  cli::cli_warn(c(
    "Column types differ across files for {.field {conflicts}} -- re-typed with {.fun readr::parse_guess}.",
    "i" = "Use {.fun daos::view_types} to inspect the differences."
  ))
  result <- lapply(result, function(d) {
    hit <- intersect(conflicts, names(d))
    d[hit] <- lapply(d[hit], as.character)
    d
  })
  bound <- dplyr::bind_rows(result, .id = .id)
  bound[conflicts] <- lapply(bound[conflicts], readr::parse_guess)
  bound
}

# read_xlsx()/read_xls() silently read only the first sheet. When a workbook
# has several and the caller did not name one, warn -- so a partial read is
# never a surprise. read_files() catches the warning by its class and reports
# all workbooks in one warning. Reading itself is unchanged.
.read_excel <- function(path, read_fn, ...) {
  if (is.null(list(...)$sheet)) {
    sheets <- tryCatch(readxl::excel_sheets(path), error = function(e) character())
    if (length(sheets) > 1)
      cli::cli_warn(
        "{.file {basename(path)}} has {length(sheets)} sheets -- read only the first ({.val {sheets[1]}}).",
        class = "daos_excel_sheets", sheets = sheets
      )
  }
  read_fn(path, ...)
}

# Same locale rule as readr::read_csv2() -- a locale without its own decimal
# mark gets the European one -- without read_csv2()'s message about it and the
# column specification on every call. Ten files would otherwise print a
# screenful; read_files() is meant to be silent on success.
.read_csv_semicolon <- function(path, ..., locale = readr::default_locale(),
                                show_col_types = FALSE) {
  if (locale$decimal_mark == ".") {
    locale$decimal_mark  <- ","
    locale$grouping_mark <- "."
  }
  readr::read_delim(path, delim = ";", locale = locale,
                    show_col_types = show_col_types, ...)
}

# Build a reader that lives in a Suggested package: check the package is
# installed (a clear error naming the format if not), then fetch and call the
# function. getExportedValue() defers the lookup to call time, so the package
# is only needed when a file of that format is actually read.
.reader_from_pkg <- function(pkg, fn, what) {
  function(...) {
    if (!requireNamespace(pkg, quietly = TRUE))
      cli::cli_abort("Package {.pkg {pkg}} is required to read {what} files.")
    getExportedValue(pkg, fn)(...)
  }
}

.read_files_readers <- function() {
  # readxl needs the sheet-aware wrapper (.read_excel), so it stays explicit;
  # the rest follow the one "needs a package" shape via .reader_from_pkg().
  readxl_reader <- function(fn) function(path, ...) {
    if (!requireNamespace("readxl", quietly = TRUE))
      cli::cli_abort("Package {.pkg readxl} is required to read Excel files.")
    .read_excel(path, getExportedValue("readxl", fn), ...)
  }
  list(
    csv      = .read_csv_semicolon,
    tsv      = function(path, ..., show_col_types = FALSE)
                 readr::read_tsv(path, show_col_types = show_col_types, ...),
    txt      = readr::read_lines,
    rds      = readRDS,
    xlsx     = readxl_reader("read_xlsx"),
    xls      = readxl_reader("read_xls"),
    parquet  = .reader_from_pkg("arrow",    "read_parquet", "parquet"),
    feather  = .reader_from_pkg("arrow",    "read_feather", "feather"),
    sas7bdat = .reader_from_pkg("haven",    "read_sas",     "SAS"),
    sav      = .reader_from_pkg("haven",    "read_sav",     "SPSS"),
    por      = .reader_from_pkg("haven",    "read_por",     "SPSS portable"),
    xpt      = .reader_from_pkg("haven",    "read_xpt",     "SAS transport"),
    dta      = .reader_from_pkg("haven",    "read_dta",     "Stata"),
    json     = .reader_from_pkg("jsonlite", "read_json",    "JSON"),
    ndjson   = .reader_from_pkg("jsonlite", "stream_in",    "NDJSON"),
    jsonl    = .reader_from_pkg("jsonlite", "stream_in",    "JSONL"),
    yaml     = .reader_from_pkg("yaml",     "read_yaml",    "YAML"),
    yml      = .reader_from_pkg("yaml",     "read_yaml",    "YAML")
  )
}
