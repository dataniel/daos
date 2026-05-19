# data.table uses non-standard evaluation — declare its special symbols so
# R CMD check does not flag them as undefined globals.
utils::globalVariables(c(".N", ".GRP", ":=", "isdup", "dupid"))

#' @importFrom rlang :=
NULL
