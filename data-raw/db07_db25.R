# Rebuild the bundled DST crosswalk from the repository root.
# Source: https://www.dst.dk/da/Statistik/dokumentation/dansk-branchekode-er-gaeldende
# Source page update: 2026-02-26. Retrieved: 2026-10-24.
# Requires readxl only when rebuilding, not when using the converter.
urls <- c(
  correspondence = "https://www.dst.dk/ext/9884313386991/0/erhvervreg/DB07_DB25_noegle_brancher-%28xlsx%29--xlsx",
  simple = "https://www.dst.dk/ext/149136687591/0/erhvervreg/Simpel-konverteringsmatrice-%28xlsx%29--xlsx"
)
read_key <- function(url, sheet) {
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path))
  download.file(url, path, mode = "wb", quiet = TRUE)
  as.data.frame(readxl::read_excel(path, sheet = sheet, col_types = "text"))
}
pairs <- read_key(urls[["correspondence"]], "DB07-DB25")
simple <- read_key(urls[["simple"]], 1)
reverse_simple <- read_key(urls[["simple"]], 2)
compact <- function(x) gsub("[.[:space:]]", "", x)
pairs <- unique(data.frame(db07 = compact(pairs$DB07), db25 = compact(pairs$DB25)))
simple <- data.frame(db07 = compact(simple$DB07), db25 = compact(simple$DB25))
reverse_simple <- data.frame(db07 = compact(reverse_simple$DB07),
                             db25 = compact(reverse_simple$DB25))
stopifnot(
  nrow(pairs) > 700L,
  all(grepl("^[0-9]{6}$", pairs$db07)),
  all(grepl("^[0-9]{6}$", pairs$db25)),
  all(grepl("^[0-9]{6}$", simple$db07)),
  all(grepl("^[0-9]{6}$", simple$db25)),
  !anyDuplicated(simple$db07),
  setequal(pairs$db07, simple$db07),
  all(paste(simple$db07, simple$db25) %in% paste(pairs$db07, pairs$db25)),
  !anyDuplicated(reverse_simple$db25),
  setequal(pairs$db25, reverse_simple$db25),
  all(paste(reverse_simple$db07, reverse_simple$db25) %in% paste(pairs$db07, pairs$db25))
)
# Keep all candidates to detect splits instead of silently choosing the first.
db07_db25_key <- split(pairs$db25, pairs$db07)
db07_db25_simple <- setNames(simple$db25, simple$db07)
db25_db07_key <- split(pairs$db07, pairs$db25)
db25_db07_simple <- setNames(reverse_simple$db07, reverse_simple$db25)
read_labels <- function(sheet, version) {
  labels <- read_key(urls[["correspondence"]], sheet)
  codes <- compact(labels[[version]])
  # DST's DB07 sheet stores divisions 01-09 as single numeric digits.
  # Repair only these known source cells, never arbitrary user input.
  single_digit <- grepl("^[0-9]$", codes)
  codes[single_digit] <- paste0("0", codes[single_digit])
  titles <- labels[[paste0(version, "_titel")]]
  stopifnot(!anyNA(codes), !anyDuplicated(codes),
            all(grepl("^([A-Z]|[0-9]{2}|[0-9]{3}|[0-9]{4}|[0-9]{6})$", codes)),
            !anyNA(titles), all(nzchar(titles)))
  setNames(enc2utf8(titles), codes)
}
db07_labels <- read_labels("4. DB07 Alle koder", "DB07")
db25_labels <- read_labels("3. DB25 Alle koder", "DB25")
stopifnot(setequal(names(db07_labels)[nchar(names(db07_labels)) == 6L], names(db07_db25_key)),
          setequal(names(db25_labels)[nchar(names(db25_labels)) == 6L], names(db25_db07_key)))
save(db07_db25_key, db07_db25_simple, db25_db07_key, db25_db07_simple,
     db07_labels, db25_labels,
     file = "R/sysdata.rda", compress = "xz", version = 2)
cat(length(db07_db25_key), "DB07 codes;", nrow(pairs), "relations;",
    sum(lengths(db07_db25_key) > 1L), "split codes\n")
