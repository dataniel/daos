#' Read an XBRL file
#'
#' Parses an XBRL XML document and returns a tidy tibble with facts joined
#' to their context and unit information.
#'
#' @param path Path to the XBRL file (`.xml` or similar).
#' @param encoding Character encoding of the file. Defaults to `"UTF-8"`.
#'
#' @return A [`tibble`][tibble::tibble] with one row per fact and columns:
#'   `elementid`, `contextid`, `fact`, `unitid`, `decimals`, `startdate`,
#'   `enddate`, `instant`, `explicit_member`, `unit`.
#'
#' @examples
#' \dontrun{
#' df <- read_xbrl("report.xml")
#' }
#'
#' @importFrom xml2 read_xml xml_find_all xml_name xml_attr xml_text xml_find_first
#' @importFrom data.table rbindlist data.table
#' @importFrom tibble as_tibble
#' @export
read_xbrl <- function(path, encoding = "UTF-8") {
  doc <- xml2::read_xml(path, encoding = encoding)

  fact_nodes    <- xml2::xml_find_all(doc, "//*[@contextRef]")
  context_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='context']")
  unit_nodes    <- xml2::xml_find_all(doc, ".//*[local-name()='unit']")

  strip_prefix <- function(x) sub("^[^:]+:", "", x)

  facts <- data.table::rbindlist(
    lapply(fact_nodes, function(node) {
      data.table::data.table(
        elementid = xml2::xml_name(node),
        contextid = strip_prefix(xml2::xml_attr(node, "contextRef")),
        fact      = xml2::xml_text(node, trim = TRUE),
        unitid    = strip_prefix(xml2::xml_attr(node, "unitRef")),
        decimals  = xml2::xml_attr(node, "decimals")
      )
    }),
    fill = TRUE
  )

  contexts <- data.table::rbindlist(
    lapply(context_nodes, function(node) {
      data.table::data.table(
        contextid       = xml2::xml_attr(node, "id"),
        startdate       = xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='startDate']"),      trim = TRUE),
        enddate         = xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='endDate']"),        trim = TRUE),
        instant         = xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='instant']"),        trim = TRUE),
        explicit_member = xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='explicitMember']"), trim = TRUE)
      )
    }),
    fill = TRUE
  )

  units <- data.table::rbindlist(
    lapply(unit_nodes, function(node) {
      data.table::data.table(
        unitid = xml2::xml_attr(node, "id"),
        unit   = xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='measure']"), trim = TRUE)
      )
    }),
    fill = TRUE
  )

  merged <- merge(facts, contexts, by = "contextid", all.x = TRUE, sort = FALSE)
  merged <- merge(merged, units,   by = "unitid",    all.x = TRUE, sort = FALSE)

  tibble::as_tibble(merged)
}
