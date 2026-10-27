#' Find cells outside the table in an Excel workbook
#'
#' Lists the blocks of non-empty cells that lie outside the area being read:
#' a note under the table, a total row set apart by an empty row, a second
#' table to the right, a title above. Returns an empty tibble when there are
#' none, so it can be used as a checkpoint.
#'
#' @details
#' **Why this exists.** `readxl` reads the smallest rectangle that holds
#' *every* non-empty cell on a sheet. A source note three rows under the
#' table therefore becomes extra data rows, and a comment two columns to the
#' right becomes a column named `...7`, without a warning. With a `range`,
#' the opposite happens: cells outside it are dropped without a word. Either
#' way the surprise is silent, and it is cheap to rule out by looking at where
#' the cells actually are.
#'
#' **Finding the table.** Without a range for a sheet, the table is the
#' largest block of cells that is not split by an entirely empty row or
#' column, which is what a person looking at the sheet would call the table.
#' Single-cell rows on top of it, such as a title with no empty row below
#' it, are left out, so the header is the first row of the area. This is the
#' area [read_workbook()] reads by default.
#'
#' **Reporting.** Cells outside the area are grouped into blocks the same
#' way and reported with their position relative to the nearest area. A
#' block above the table with at most one cell per row, in any column, is
#' reported as a `"title"`. When reading by `table`, cells that belong to any
#' defined table on the sheet are never reported, so two tables side by side
#' do not report each other.
#'
#' Only cells with a value count; formatting, borders and empty strings do
#' not. The cells are found with `readxl` itself, reading the sheet once as
#' text, so the check costs about one extra read and agrees with `readxl` on
#' what is empty.
#'
#' @param path Path to an Excel file (`.xlsx`, `.xlsm` or `.xls`).
#' @param sheet Sheet names or positions. `NULL` (default) means every sheet.
#' @param range The area to read, where the default `NULL` finds the table on
#'   each sheet. One range, such as `"B3:F40"` (with a single `sheet`) or
#'   `"Sheet1!B3:F40"`; or one per sheet as a named vector,
#'   `c(Sheet1 = "B3:F40", Sheet2 = NA)`, where `NA` means find the table.
#'   Sheets not named are found automatically.
#' @param table Names of defined Excel tables (Insert > Table), or `TRUE` for
#'   all of them. Cannot be combined with `sheet` or `range`. `.xlsx` and
#'   `.xlsm` only, and needs the `xml2` package.
#' @param skip Rows at the top of each sheet to leave out before the table is
#'   found, as in `readxl::read_excel()`. Not used for a given `range` or
#'   `table`.
#'
#' @return A tibble with one row per block outside the read area: `sheet`,
#'   `area` (the area read, such as `"B3:F40"` or `"Sales (B3:F40)"`),
#'   `block` (the block's range), `position` (`"title"`, `"above"`,
#'   `"below"`, `"left"`, `"right"`, a combination such as `"below right"`,
#'   or `"around"` for a block that wraps a corner), `cells` (non-empty cells
#'   in the block) and `first` (the first value in the block, for
#'   recognition).
#'
#' @examples
#' \dontrun{
#' inspect_excel("data/report.xlsx")
#' inspect_excel("data/report.xlsx", table = TRUE)
#'
#' inspect_excel("data/report.xlsx", range = "Sheet1!B3:F40") |>
#'   expectr::expect_empty(warn_msg = "cells outside the table")
#' }
#'
#' @seealso [daos::read_workbook()], which reads the same areas and runs this
#'   check.
#' @export
inspect_excel <- function(path, sheet = NULL, range = NULL, table = NULL, skip = 0) {
  .excel_check_path(path)
  plan <- .excel_plan(path, sheet, range, table)
  plan <- .excel_detect(path, plan, skip)
  .excel_inspect(path, plan)
}

# Planning -----------------------------------------------------------------

.excel_check_path <- function(path, call = rlang::caller_env()) {
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.", call = call)
  }
  if (!file.exists(path)) {
    cli::cli_abort("File {.file {path}} does not exist.", call = call)
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg readxl} is required to read Excel files.", call = call)
  }
  # An .xlsx is a zip. One with a password to open is instead an encrypted
  # OLE container, which readxl cannot read and reports with an unrelated
  # zip error. Sheet and workbook protection (no password to open) do not
  # encrypt the file and read fine.
  if (.is_xlsx(path) && identical(readBin(path, "raw", 8), as.raw(c(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1)))) {
    cli::cli_abort(c(
      "{.file {basename(path)}} is password-protected, or an {.file .xls} file named {.file .{tools::file_ext(path)}}.",
      "i" = "readxl cannot read encrypted workbooks. Save a copy without the password to open, or rename it to {.file .xls} if it is an old Excel file."
    ), call = call)
  }
}

# Defined tables are read from the file's XML
.excel_need_xml2 <- function(why, call = rlang::caller_env()) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    cli::cli_abort(c("Package {.pkg xml2} is required to {why}.", "i" = "Install it with {.code install.packages(\"xml2\")}."), call = call)
  }
}

.is_xlsx <- function(path) tolower(tools::file_ext(path)) %in% c("xlsx", "xlsm")

# What to read: one row per sheet or table, with the range to read (NA: find
# the table, see .excel_detect()). Shared by read_workbook() and
# inspect_excel(), so the check always looks at exactly what was read.
# `single` says whether the caller named one thing and should get it back
# without a list around it.
.excel_plan <- function(path, sheet, range, table, call = rlang::caller_env()) {
  if (!is.null(table)) {
    if (!is.null(sheet) || !is.null(range)) {
      cli::cli_abort(c(
        "Use {.arg table} on its own.",
        "i" = "A table already names its sheet and range."
      ), call = call)
    }
    if (!.is_xlsx(path)) {
      cli::cli_abort("Defined tables can only be read from {.file .xlsx} and {.file .xlsm} files.", call = call)
    }
    .excel_need_xml2("read defined tables", call = call)
    tabs <- .xlsx_tables(path)
    if (nrow(tabs) == 0) {
      cli::cli_abort("{.file {basename(path)}} has no defined tables.", call = call)
    }
    if (isTRUE(table)) {
      sel <- tabs
    } else {
      if (!is.character(table)) {
        cli::cli_abort("{.arg table} must be table names or {.code TRUE}.", call = call)
      }
      unknown <- setdiff(table, tabs$name)
      if (length(unknown) > 0) {
        cli::cli_abort(c(
          "{.file {basename(path)}} has no table{?s} named {.val {unknown}}.",
          "i" = "Tables: {.val {tabs$name}}."
        ), call = call)
      }
      sel <- tabs[match(table, tabs$name), ]
    }
    plan <- data.frame(name = sel$name, sheet = sel$sheet, range = sel$range, detected = FALSE)
    attr(plan, "mode") <- "table"
    attr(plan, "single") <- !isTRUE(table) && length(table) == 1
    return(plan)
  }

  all_sheets <- readxl::excel_sheets(path)
  single <- length(sheet) == 1

  # One unnamed range belongs to one sheet: the one written in it, or `sheet`
  if (!is.null(range)) {
    if (!is.character(range) && !all(is.na(range))) {
      cli::cli_abort("{.arg range} must be a string such as {.val B3:F40}, or a named vector of them.", call = call)
    }
    if (is.null(names(range))) {
      if (length(range) != 1) {
        cli::cli_abort(c(
          "Several ranges need the sheets they belong to.",
          "i" = 'Name them: {.code range = c(Sheet1 = "B3:F40", Sheet2 = "A1:D9")}.'
        ), call = call)
      }
      if (grepl("!", range, fixed = TRUE)) {
        in_range <- gsub("^'|'$", "", sub("!.*$", "", range))
        if (!is.null(sheet) && !identical(as.character(sheet), in_range)) {
          cli::cli_abort("{.arg range} names sheet {.val {in_range}}, but {.arg sheet} is {.val {sheet}}.", call = call)
        }
        sheet <- in_range
        range <- sub("^.*!", "", range)
      }
      if (length(sheet) != 1) {
        cli::cli_abort(c(
          "{.arg range} needs one sheet.",
          "i" = 'Give {.arg sheet}, write the range as {.val Sheet1!B3:F40}, or give one range per sheet: {.code range = c(Sheet1 = "B3:F40")}.'
        ), call = call)
      }
      single <- TRUE
    }
  }

  if (is.null(sheet)) {
    sheet <- all_sheets
  } else if (is.numeric(sheet)) {
    bad <- sheet[sheet < 1 | sheet > length(all_sheets) | sheet != round(sheet)]
    if (length(bad) > 0) {
      cli::cli_abort("{.file {basename(path)}} has {length(all_sheets)} sheet{?s}; there is no sheet {.val {bad}}.", call = call)
    }
    sheet <- all_sheets[sheet]
  } else {
    unknown <- setdiff(sheet, all_sheets)
    if (length(unknown) > 0) {
      cli::cli_abort(c(
        "{.file {basename(path)}} has no sheet{?s} named {.val {unknown}}.",
        "i" = "Sheets: {.val {all_sheets}}."
      ), call = call)
    }
  }

  ranges <- stats::setNames(rep(NA_character_, length(sheet)), sheet)
  if (!is.null(range)) {
    if (is.null(names(range))) names(range) <- sheet
    if (any(is.na(names(range)) | names(range) == "")) {
      cli::cli_abort("Every range in {.arg range} needs a sheet name.", call = call)
    }
    not_read <- setdiff(names(range), sheet)
    if (length(not_read) > 0) {
      cli::cli_abort(c(
        "{.arg range} names sheet{?s} {.val {not_read}}, which {?is/are} not read.",
        "i" = if (any(not_read %in% all_sheets)) "Add {cli::qty(not_read)}{?it/them} to {.arg sheet}." else "Sheets: {.val {all_sheets}}."
      ), call = call)
    }
    clean <- toupper(gsub("$", "", range, fixed = TRUE))
    bad <- range[!is.na(clean) & !grepl("^[A-Z]{1,3}[0-9]+(:[A-Z]{1,3}[0-9]+)?$", clean)]
    if (length(bad) > 0) {
      cli::cli_abort("{.val {bad}} {?is not a cell range/are not cell ranges} such as {.val B3:F40}.", call = call)
    }
    ranges[names(range)] <- clean
  }

  plan <- data.frame(name = sheet, sheet = sheet, range = unname(ranges), detected = FALSE)
  attr(plan, "mode") <- "sheet"
  attr(plan, "single") <- single
  plan
}

# Fill in the ranges left NA with the table found on the sheet. An empty
# sheet stays NA and is read whole.
.excel_detect <- function(path, plan, skip = 0) {
  attr(plan, "skip") <- skip
  if (!anyNA(plan$range)) return(plan)
  # Keep the cells for .excel_inspect(), so each sheet is scanned once
  cache <- list()
  for (i in which(is.na(plan$range))) {
    cells <- .excel_cells(path, plan$sheet[i])
    cache[[plan$sheet[i]]] <- cells
    cells <- cells[cells$row > skip, ]
    if (nrow(cells) == 0) next
    plan$range[i] <- .excel_main_area(cells)
    plan$detected[i] <- TRUE
  }
  attr(plan, "cells") <- cache
  plan
}

.excel_main_area <- function(cells) {
  blocks <- .xy_blocks(cells$row, cells$col)
  b <- cells[blocks[[which.max(lengths(blocks))]], ]
  # A title (or a stack of them) directly on top of the table, with no empty
  # row in between, is in the same block. Leave single-cell top rows out of
  # a wider block, so the header is read as the header.
  repeat {
    top <- b$row == min(b$row)
    if (sum(top) != 1 || all(top) || length(unique(b$col)) < 2) break
    b <- b[!top, ]
  }
  .rc_range(min(b$row), max(b$row), min(b$col), max(b$col))
}

# Inspection ---------------------------------------------------------------

.excel_inspect <- function(path, plan) {
  mode <- attr(plan, "mode")
  tabs <- if (mode == "table") .xlsx_tables(path)

  found <- lapply(unique(plan$sheet), function(sh) {
    if (mode == "table") {
      on_sheet <- tabs[tabs$sheet == sh, ]
      areas <- .range_rect(on_sheet$range)
      areas$label <- paste0(on_sheet$name, " (", on_sheet$range, ")")
    } else {
      rng <- plan$range[plan$sheet == sh]
      if (is.na(rng)) return(NULL)   # empty sheet
      areas <- .range_rect(rng)
      areas$label <- rng
    }
    cells <- attr(plan, "cells")[[sh]] %||% .excel_cells(path, sh)
    # Rows the caller skipped are left out on purpose, not by surprise
    if (any(plan$detected[plan$sheet == sh])) cells <- cells[cells$row > attr(plan, "skip"), ]

    inside <- Reduce(`|`, lapply(seq_len(nrow(areas)), function(a) {
      cells$row >= areas$r1[a] & cells$row <= areas$r2[a] &
        cells$col >= areas$c1[a] & cells$col <= areas$c2[a]
    }))
    out <- cells[!inside, ]
    if (nrow(out) == 0) return(NULL)

    rows <- lapply(.xy_blocks(out$row, out$col), function(i) {
      b <- out[i, ]
      r1 <- min(b$row); r2 <- max(b$row); c1 <- min(b$col); c2 <- max(b$col)
      dist <- pmax(0, areas$r1 - r2, r1 - areas$r2) + pmax(0, areas$c1 - c2, c1 - areas$c2)
      a <- which.min(dist)
      vert <- if (r2 < areas$r1[a]) "above" else if (r1 > areas$r2[a]) "below" else ""
      horz <- if (c2 < areas$c1[a]) "left" else if (c1 > areas$c2[a]) "right" else ""
      pos <- trimws(paste(vert, horz))
      if (pos == "") pos <- "around"
      if (vert == "above" && !anyDuplicated(b$row)) pos <- "title"
      b <- b[order(b$row, b$col), ]
      data.frame(
        sheet = sh, area = areas$label[a], block = .rc_range(r1, r2, c1, c2),
        position = pos, cells = nrow(b), first = b$value[1], r1 = r1, c1 = c1
      )
    })
    do.call(rbind, rows)
  })

  found <- do.call(rbind, found)
  if (is.null(found)) {
    return(tibble::tibble(sheet = character(), area = character(), block = character(),
                          position = character(), cells = integer(), first = character()))
  }
  found <- found[order(match(found$sheet, plan$sheet), found$r1, found$c1), ]
  tibble::as_tibble(found[c("sheet", "area", "block", "position", "cells", "first")])
}

# Non-empty cells of one sheet: row, col and the value as text. readxl reads
# the sheet as a text grid anchored at A1, so positions are absolute and
# empty leading rows and columns are kept. This is readxl's own fast reader,
# for .xlsx and .xls alike, and it agrees with readxl on what is empty.
.excel_cells <- function(path, sheet) {
  grid <- readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, col_types = "text",
    range = readxl::cell_limits(c(1, 1), c(NA, NA)),
    .name_repair = "minimal", progress = FALSE
  )
  filled <- lapply(grid, function(x) which(!is.na(x)))
  data.frame(
    row   = unlist(filled, use.names = FALSE),
    col   = rep(seq_along(grid), lengths(filled)),
    value = unlist(Map(`[`, grid, filled), use.names = FALSE) %||% character()
  )
}

# Split cells into blocks at entirely empty rows, then entirely empty
# columns, recursively (an XY-cut). Faster than connected components on a
# sheet with millions of cells, and it matches how a person sees blocks: a
# table with a few blank cells inside stays one block.
.xy_blocks <- function(r, c) {
  split_at_gaps <- function(v) {
    u <- sort(unique(v))
    findInterval(v, u[c(TRUE, diff(u) > 1L)])
  }
  cut <- function(i) {
    by_row <- split_at_gaps(r[i])
    if (max(by_row) > 1) return(unlist(lapply(split(i, by_row), cut), recursive = FALSE))
    by_col <- split_at_gaps(c[i])
    if (max(by_col) > 1) return(unlist(lapply(split(i, by_col), cut), recursive = FALSE))
    list(i)
  }
  unname(cut(seq_along(r)))
}

# Defined tables ---------------------------------------------------------------
# An .xlsx file is a zip of XML parts. readxl does not know defined tables,
# so their names and ranges are read from the few parts involved with xml2.

.xlsx_part <- function(path, part) xml2::read_xml(unz(path, part))

# XPath by local element name, so it works whatever namespaces a part
# declares, without xml_ns_strip() rewriting every node.
.xp <- function(...) paste0("*[local-name()='", c(...), "']", collapse = "/")

.xlsx_has_part <- function(path, part) part %in% utils::unzip(path, list = TRUE)$Name

# Resolve a relationship target against the folder of the part that points
# to it ("../tables/table1.xml" from "xl/worksheets").
.xlsx_resolve <- function(base, target) {
  if (startsWith(target, "/")) return(sub("^/", "", target))
  out <- character()
  for (p in strsplit(paste0(base, "/", target), "/", fixed = TRUE)[[1]]) {
    if (p == "..") out <- utils::head(out, -1) else if (!p %in% c("", ".")) out <- c(out, p)
  }
  paste(out, collapse = "/")
}

.xlsx_rels <- function(path, part) {
  rels_part <- file.path(dirname(part), "_rels", paste0(basename(part), ".rels"))
  if (!.xlsx_has_part(path, rels_part)) {
    return(data.frame(id = character(), type = character(), part = character()))
  }
  rel <- xml2::xml_find_all(.xlsx_part(path, rels_part), paste0("//", .xp("Relationship")))
  data.frame(
    id   = xml2::xml_attr(rel, "Id"),
    type = basename(xml2::xml_attr(rel, "Type")),
    part = vapply(xml2::xml_attr(rel, "Target"), function(t) .xlsx_resolve(dirname(part), t), character(1))
  )
}

# Named vector: sheet name -> worksheet part
.xlsx_sheet_parts <- function(path) {
  sheets <- xml2::xml_find_all(.xlsx_part(path, "xl/workbook.xml"), paste0("//", .xp("sheets", "sheet")))
  rels <- .xlsx_rels(path, "xl/workbook.xml")
  # The relationship id is a namespaced attribute (r:id); match it by suffix
  ids <- vapply(xml2::xml_attrs(sheets), function(a) unname(a[grepl("(^|:)id$", names(a))][1]), character(1))
  stats::setNames(rels$part[match(ids, rels$id)], xml2::xml_attr(sheets, "name"))
}

# Defined tables: name, sheet, and the range to read. A totals row is part of
# the table's ref but not data, so it is left out of the range.
.xlsx_tables <- function(path) {
  parts <- .xlsx_sheet_parts(path)
  tabs <- lapply(names(parts), function(sh) {
    rels <- .xlsx_rels(path, parts[[sh]])
    rels <- rels[rels$type == "table", ]
    lapply(rels$part, function(p) {
      t <- xml2::xml_root(.xlsx_part(path, p))
      rect <- .range_rect(xml2::xml_attr(t, "ref"))
      totals <- as.integer(xml2::xml_attr(t, "totalsRowCount") %|NA|% "0")
      data.frame(
        name  = xml2::xml_attr(t, "displayName") %|NA|% xml2::xml_attr(t, "name"),
        sheet = sh,
        range = .rc_range(rect$r1, rect$r2 - totals, rect$c1, rect$c2)
      )
    })
  })
  out <- do.call(rbind, unlist(tabs, recursive = FALSE))
  out %||% data.frame(name = character(), sheet = character(), range = character())
}

`%|NA|%` <- function(x, y) if (is.na(x)) y else x

# Cell references -------------------------------------------------------------

.ref_rc <- function(ref) {
  ref <- toupper(gsub("$", "", ref, fixed = TRUE))
  letters_part <- sub("[0-9]+$", "", ref)
  n <- nchar(letters_part)
  digit <- function(k) {
    d <- match(substr(letters_part, n - k, n - k), LETTERS)
    ifelse(n > k, d, 0)
  }
  list(row = as.integer(sub("^[A-Z]+", "", ref)),
       col = as.integer(digit(0) + 26 * digit(1) + 676 * digit(2)))
}

.col_letters <- function(col) {
  vapply(col, function(x) {
    s <- ""
    while (x > 0) {
      s <- paste0(LETTERS[(x - 1) %% 26 + 1], s)
      x <- (x - 1) %/% 26
    }
    s
  }, character(1))
}

.rc_range <- function(r1, r2, c1, c2) {
  from <- paste0(.col_letters(c1), r1)
  to   <- paste0(.col_letters(c2), r2)
  ifelse(from == to, from, paste0(from, ":", to))
}

.range_rect <- function(range) {
  ends <- strsplit(range, ":", fixed = TRUE)
  from <- .ref_rc(vapply(ends, `[`, character(1), 1))
  to   <- .ref_rc(vapply(ends, function(e) e[length(e)], character(1)))
  data.frame(r1 = from$row, r2 = to$row, c1 = from$col, c2 = to$col)
}
