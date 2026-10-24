# Run from the daos root:
# Rscript benchmarks/benchmark-statgs.R path/to/statgs/R/pnr.R statgs_commit
# The private statgs source is deliberately not copied into this repository.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L, file.exists(args[1L]))
pkgload::load_all(quiet = TRUE, recompile = FALSE)
statgs <- new.env()
sys.source(args[1L], envir = statgs)
invisible(loadNamespace("dplyr"))
invisible(loadNamespace("tibble"))

set.seed(20261023)
nmax <- 10000L
births <- as.Date("1960-01-01") + sample.int(21915L, nmax, replace = TRUE) - 1L
# Digit 7 = 1 for 1900s, 4 for 2000s. Valid encoded dates, not assigned IDs.
pnr <- paste0(format(births, "%d%m%y"),
              ifelse(format(births, "%Y") < "2000", "1", "4"),
              sprintf("%03d", sample.int(999L, nmax, replace = TRUE)))
years <- sample(2020:2026, nmax, replace = TRUE)
dates <- as.Date(paste0(years, "-01-01"))
rows <- list()

for (n in c(1000L, 10000L)) {
  df <- data.frame(pnr = pnr[seq_len(n)], year = years[seq_len(n)])
  refs <- dates[seq_len(n)]
  cases <- list(
    age_scalar = list(
      daos = function() add_cpr_info(df, pnr, age(date = "2026-07-01"))$age,
      statgs = function() statgs$age(df$pnr, date = "2026-07-01")),
    age_row_dates = list(
      daos = function() add_cpr_info(df, pnr, age(date = refs))$age,
      statgs = function() statgs$age(df$pnr, date = refs)),
    age_row_years = list(
      daos = function() add_cpr_info(df, pnr, age(year))$age,
      statgs = function() statgs$age(df$pnr, date = refs)),
    birth_date = list(
      daos = function() add_cpr_info(df, pnr, bday)$bday,
      statgs = function() statgs$dob(df$pnr)),
    all_outputs = list(
      daos = function() add_cpr_info(df, pnr, bday, age(date = "2026-07-01"), sex, mod11, valid),
      statgs = function() {
        out <- df
        out$pnr <- statgs$clean(df$pnr)
        out$bday <- statgs$dob(df$pnr)
        out$age <- statgs$age(df$pnr, date = "2026-07-01")
        out$sex <- statgs$gender(df$pnr, female = 0, male = 1)
        out$mod11 <- statgs$mod11(df$pnr)
        out$valid <- !is.na(out$bday)
        out
      })
  )
  for (case in names(cases)) {
    pair <- cases[[case]]
    a <- pair$daos()
    b <- pair$statgs()
    if (case == "all_outputs") {
      stopifnot(identical(a$bday, b$bday), all(a$sex == b$sex),
                identical(a$mod11, b$mod11), identical(a$valid, b$valid))
      mismatches <- sum(a$age != b$age)
    } else {
      mismatches <- sum(a != b)
      if (case == "birth_date") stopifnot(mismatches == 0L)
    }
    timings <- matrix(NA_real_, 3L, 2L, dimnames = list(NULL, c("daos", "statgs")))
    for (rep in seq_len(3L)) {
      # Alternate order; collect garbage outside the timed region.
      for (impl in if (rep %% 2L) c("daos", "statgs") else c("statgs", "daos")) {
        gc()
        batch <- if (impl == "daos") 50L else 1L
        timings[rep, impl] <- system.time(for (i in seq_len(batch)) pair[[impl]]())[["elapsed"]] / batch
      }
    }
    row <- data.frame(case = case, n = n,
                      daos_seconds = median(timings[, "daos"]),
                      statgs_seconds = median(timings[, "statgs"]),
                      mismatches = mismatches)
    row$speedup <- row$statgs_seconds / row$daos_seconds
    rows[[length(rows) + 1L]] <- row
    print(row, row.names = FALSE)
    flush.console()
    write.csv(do.call(rbind, rows), "benchmarks/statgs-results.csv", row.names = FALSE)
  }
}

# Explicit birthday example showing the different age definitions.
edge <- data.frame(pnr = "0101014007")
print(data.frame(date = "2026-01-01",
                 daos = add_cpr_info(edge, pnr, age(date = "2026-01-01"))$age,
                 statgs = statgs$age(edge$pnr, date = "2026-01-01")))
writeLines(c(paste("statgs commit:", args[2L]),
             paste("daos commit:", system("git rev-parse HEAD", intern = TRUE)),
             "Synthetic valid-format CPRs; 3 timed repetitions after warmup.",
             "Each daos repetition averages 50 calls to avoid timer resolution issues.",
             "Row dates precomputed for both; year case uses daos year shortcut.",
             "All outputs: statgs validity derived from dob; female recoded to 0.",
             "Timing includes daos data-frame output overhead; no I/O in timed code.",
             capture.output(sessionInfo())), "benchmarks/statgs-session.txt")
