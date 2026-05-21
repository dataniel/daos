#' Read data from a Microsoft Access database
#'
#' Connects to a Microsoft Access database (`.mdb` or `.accdb`) via ODBC,
#' executes a SQL query, and returns the result as a tibble.
#'
#' @param path Path to the Access database file. Can be a string or an
#'   [`fs::path`] object. Both `.mdb` and `.accdb` files are supported.
#' @param sql A SQL query string to execute against the database.
#' @param verbosity Level of status output. One of:
#'   * `"full"` – header, per-step spinners, and summary. Best for interactive
#'     single-file use.
#'   * `"compact"` – a single-line summary per file. Best when iterating over
#'     many databases. This is the default.
#'   * `"quiet"` – no output.
#'
#' @return A [`tibble`][tibble::tibble] containing the query result.
#'
#' @examples
#' \dontrun{
#' # single file – use full output
#' data <- read_access("sales.mdb", "SELECT * FROM Customers",
#'                     verbosity = "full")
#'
#' # many files – compact output is the default
#' files <- fs::dir_ls("data", glob = "*.mdb")
#' all_data <- files |>
#'   purrr::map(\(f) read_access(f, "SELECT * FROM Sales"))
#' }
#'
#' @importFrom rlang arg_match
#' @importFrom cli cli_abort cli_h1 cli_alert_info cli_alert_success cli_progress_step cli_progress_done cli_rule
#' @importFrom fs file_exists path_abs path_file
#' @importFrom glue glue
#' @importFrom tibble as_tibble
#' @export
read_access <- function(path, sql, verbosity = c("compact", "full", "quiet")) {
  verbosity <- rlang::arg_match(verbosity)

  if (!is.character(sql) || length(sql) != 1 || !nzchar(sql)) {
    cli::cli_abort("{.arg sql} must be a single non-empty string.")
  }
  if (!fs::file_exists(path)) {
    cli::cli_abort("File {.file {path}} does not exist.")
  }

  if (!requireNamespace("DBI", quietly = TRUE))
    cli::cli_abort("Package {.pkg DBI} is required to use {.fn read_access}.")
  if (!requireNamespace("odbc", quietly = TRUE))
    cli::cli_abort("Package {.pkg odbc} is required to use {.fn read_access}.")

  drivers <- odbc::odbcListDrivers()
  access_driver <- drivers$name |>
    unique() |>
    (\(x) x[grepl("Access", x, ignore.case = TRUE)])() |>
    head(1)

  if (length(access_driver) == 0) {
    cli::cli_abort(c(
      "No Microsoft Access ODBC driver found on this system.",
      "i" = "Install the {.emph Microsoft Access Database Engine Redistributable}.",
      "i" = "Check installed drivers with {.code odbc::odbcListDrivers()}."
    ))
  }

  conn_str <- glue::glue("Driver={{{access_driver}}};DBQ={fs::path_abs(path)};")

  if (verbosity == "full") {
    cli::cli_h1("Reading Access database")
    cli::cli_alert_info("File: {.file {fs::path_file(path)}}")
    cli::cli_alert_info("Driver: {.val {access_driver}}")

    t_connect <- Sys.time()
    cli::cli_progress_step("Connecting to database", spinner = TRUE)
    con <- DBI::dbConnect(odbc::odbc(), .connection_string = conn_str)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    cli::cli_progress_done()
    cli::cli_alert_success("Connected {format_elapsed(Sys.time() - t_connect)}")

    t_query <- Sys.time()
    cli::cli_progress_step("Executing query", spinner = TRUE)
    data <- DBI::dbGetQuery(con, sql) |> tibble::as_tibble()
    cli::cli_progress_done()
    cli::cli_alert_success("Query executed {format_elapsed(Sys.time() - t_query)}")

    cli::cli_alert_success(
      "Loaded {.strong {format(nrow(data), big.mark = ',')}} row{?s} and {.strong {ncol(data)}} column{?s}."
    )
    cli::cli_rule()
    return(data)
  }

  if (verbosity == "quiet") {
    con <- DBI::dbConnect(odbc::odbc(), .connection_string = conn_str)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    return(DBI::dbGetQuery(con, sql) |> tibble::as_tibble())
  }

  t_start <- Sys.time()
  con <- DBI::dbConnect(odbc::odbc(), .connection_string = conn_str)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  data <- DBI::dbGetQuery(con, sql) |> tibble::as_tibble()

  cli::cli_alert_success(
    "{.file {fs::path_file(path)}}: {.strong {format(nrow(data), big.mark = ',')}} \u00d7 {ncol(data)} {.timestamp {format_elapsed(Sys.time() - t_start)}}"
  )

  data
}
