# Run: Rscript benchmarks/benchmark-cpr.R
# Synthetic inputs only. Results compare the pre-optimisation API with current code.
pkgbuild::compile_dll(debug = FALSE, force = TRUE, quiet = TRUE)
pkgload::load_all(quiet = TRUE, recompile = FALSE)
baseline <- new.env(parent = globalenv())
sys.source("benchmarks/baseline-cpr-ux.R", baseline)
set.seed(42)
rows <- list()
sizes <- as.integer(commandArgs(trailingOnly = TRUE))
if (!length(sizes)) sizes <- c(1000L, 100000L, 1000000L)
for (n in sizes) {
  # Format the small date domain once; sampling still produces independent
  # synthetic rows. Data generation is outside all measured regions.
  birth_pool <- as.Date("1960-01-01") + 0:21914
  birth_index <- sample.int(length(birth_pool), n, replace = TRUE)
  prefixes <- paste0(format(birth_pool, "%d%m%y"),
                     ifelse(format(birth_pool, "%Y") < "2000", "1", "4"))
  pnr <- paste0(prefixes[birth_index], sprintf("%03d", sample.int(999L, n, replace = TRUE)))
  mixed <- pnr
  ix <- seq.int(1L, n, 3L)
  mixed[ix] <- paste0(substr(pnr[ix], 1L, 6L), "-", substr(pnr[ix], 7L, 10L))
  mixed[seq.int(2L, n, 31L)] <- NA_character_
  mixed[seq.int(3L, n, 41L)] <- "bad"
  df <- data.frame(pnr = mixed, year = sample(2020:2026, n, replace = TRUE))
  date_pool <- as.Date(paste0(2020:2026, "-07-01"))
  df$date <- date_pool[df$year - 2019L]
  df$text_date <- as.character(date_pool)[df$year - 2019L]
  cleaned <- df
  cleaned$pnr <- clean_cpr(df$pnr)
  cases <- list(
    clean_canonical = function(api) api$clean_cpr(pnr),
    clean_mixed = function(api) api$clean_cpr(mixed),
    age_year = function(api) api$add_cpr_info(df, pnr, age(year)),
    age_date = function(api) api$add_cpr_info(df, pnr, age(date = date)),
    age_text_date = function(api) api$add_cpr_info(df, pnr, age(date = text_date)),
    all = function(api) api$add_cpr_info(df, pnr),
    multiple_ages = function(api) api$add_cpr_info(df, pnr,
      primo = age(year), medio = age(year, "medio"), ultimo = age(year, "ultimo"), sex, bday),
    precleaned = function(api) api$add_cpr_info(cleaned, pnr, age(year), sex, bday),
    clean_then_add = function(api) {
      x <- df
      x$pnr <- api$clean_cpr(x$pnr)
      api$add_cpr_info(x, pnr, age(year), sex, bday)
    }
  )
  for (case in names(cases)) {
    f <- cases[[case]]
    current <- asNamespace("daos")
    stopifnot(identical(f(baseline), f(current)))
    times <- matrix(NA_real_, 3L, 2L)
    for (rep in 1:3) {
      for (impl in if (rep %% 2) 1:2 else 2:1) {
        gc()
        api <- if (impl == 1) baseline else current
        batch <- if (n == 1000L) 100L else 1L
        start <- Sys.time()
        for (i in seq_len(batch)) invisible(f(api))
        times[rep, impl] <- as.numeric(difftime(Sys.time(), start, units = "secs")) / batch
      }
    }
    row <- data.frame(n = n, case = case, before = median(times[, 1]), after = median(times[, 2]))
    row$speedup <- row$before / row$after
    rows[[length(rows) + 1L]] <- row
    print(row, row.names = FALSE)
    flush.console()
    write.csv(do.call(rbind, rows), "benchmarks/cpr-results.csv", row.names = FALSE)
  }
}
writeLines(c("Release compilation (-O2); median of 3 repetitions; alternating order.",
             "All outputs checked with identical() against the API snapshot.",
             capture.output(sessionInfo())), "benchmarks/cpr-session.txt")
