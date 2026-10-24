# Total R allocation, not peak resident memory.
pkgload::load_all(quiet = TRUE, recompile = FALSE)
baseline <- new.env(parent = globalenv())
sys.source("benchmarks/baseline-cpr-ux.R", baseline)
df <- data.frame(pnr = rep(c("0101004007", "111111-1118", "101004007", NA, "bad"), 200000), year = 2025L)
canonical <- rep("0101004007", nrow(df))
cases <- list(
  all = function(api) api$add_cpr_info(df, pnr),
  multiple_ages = function(api) api$add_cpr_info(df, pnr,
    primo = age(year), ultimo = age(year, "ultimo"), sex, bday),
  clean_canonical = function(api) api$clean_cpr(canonical)
)
rows <- list()
for (case in names(cases)) {
  for (impl in c("before", "after")) {
    api <- if (impl == "before") baseline else asNamespace("daos")
    f <- cases[[case]]
    invisible(f(api))
    gc()
    path <- tempfile()
    Rprofmem(path)
    invisible(f(api))
    Rprofmem(NULL)
    lines <- readLines(path)
    unlink(path)
    bytes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
    rows[[length(rows) + 1L]] <- data.frame(case = case, implementation = impl,
      allocated_mb = sum(bytes, na.rm = TRUE) / 1024^2)
  }
}
result <- do.call(rbind, rows)
print(result, row.names = FALSE)
write.csv(result, "benchmarks/cpr-memory.csv", row.names = FALSE)
