# data.table uses non-standard evaluation — declare its special symbols so
# R CMD check does not flag them as undefined globals.
utils::globalVariables(c(":=", ".end", ".unit", ".start"))

#' @importFrom rlang :=
NULL

# data.table only treats `dt[, x := ...]` as data.table syntax in packages
# that import it. daos calls data.table with `::`, so it says so here; the
# import used to come with flag_duplicates(), which moved to expectr.
.datatable.aware <- TRUE
