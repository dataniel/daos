#' Readers and writers, now in the lazer package
#'
#' The readers and writers moved from daos to the lazer package, so the
#' economics team has one place for them and new readers can be added there:
#' [lazer::read_files()], [lazer::read_workbook()], [lazer::inspect_excel()],
#' [lazer::write_excel()], [lazer::read_access()], and the TA functions
#' [lazer::read_ta()], [lazer::write_ta()] and [lazer::convert_ta()]. See
#' `vignette("lazer", package = "lazer")`.
#'
#' daos keeps a function of the same name for each, so existing scripts
#' keep working. It calls lazer and says once per session that the function
#' has moved. The four TA functions keep their old signatures; in lazer the
#' layout is an argument:
#'
#' | daos | lazer |
#' |------|-------|
#' | `read_ta(ta)` | `read_ta(path, version = 1)` |
#' | `read_ta2(path)` | `read_ta(path, version = 2)` |
#' | `write_ta(x, path)` | `write_ta(x, path, version = 1)` |
#' | `write_ta2(x, path)` | `write_ta(x, path, version = 2)` |
#'
#' New code should call lazer directly, e.g. with `library(lazer)`.
#'
#' @param ... Passed on to the lazer function of the same name.
#' @param .envir Passed on to [lazer::read_files()]: the environment for glue
#'   interpolation and unpacking, by default the caller's.
#' @param ta,path Path to the TA file.
#' @param x A data frame to write.
#'
#' @return What the lazer function returns.
#'
#' @name moved-to-lazer
#' @keywords internal
NULL

#' @rdname moved-to-lazer
#' @export
read_files <- function(..., .envir = parent.frame()) {
  moved_to_lazer("read_files()")
  lazer::read_files(..., .envir = .envir)
}

#' @rdname moved-to-lazer
#' @export
read_workbook <- function(...) {
  moved_to_lazer("read_workbook()")
  lazer::read_workbook(...)
}

#' @rdname moved-to-lazer
#' @export
inspect_excel <- function(...) {
  moved_to_lazer("inspect_excel()")
  lazer::inspect_excel(...)
}

#' @rdname moved-to-lazer
#' @export
write_excel <- function(...) {
  moved_to_lazer("write_excel()")
  lazer::write_excel(...)
}

#' @rdname moved-to-lazer
#' @export
read_access <- function(...) {
  moved_to_lazer("read_access()")
  lazer::read_access(...)
}

#' @rdname moved-to-lazer
#' @export
read_ta <- function(ta) {
  moved_to_lazer("read_ta()", "read_ta(path, version = 1)")
  lazer::read_ta(ta, version = 1)
}

#' @rdname moved-to-lazer
#' @export
read_ta2 <- function(path) {
  moved_to_lazer("read_ta2()", "read_ta(path, version = 2)")
  lazer::read_ta(path, version = 2)
}

#' @rdname moved-to-lazer
#' @export
write_ta <- function(x, path) {
  moved_to_lazer("write_ta()", "write_ta(x, path, version = 1)")
  lazer::write_ta(x, path, version = 1)
}

#' @rdname moved-to-lazer
#' @export
write_ta2 <- function(x, path) {
  moved_to_lazer("write_ta2()", "write_ta(x, path, version = 2)")
  lazer::write_ta(x, path, version = 2)
}

moved_to_lazer <- function(fun, target = fun) {
  rlang::inform(
    c(paste0("The readers and writers have moved to the lazer package; daos forwards `",
             fun, "` to `lazer::", target, "`."),
      "i" = "Use `library(lazer)` in new code. This message is shown once per session."),
    .frequency = "once", .frequency_id = "daos_moved_to_lazer",
    class = "daos_moved_to_lazer"
  )
}
