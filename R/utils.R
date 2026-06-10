format_elapsed <- function(x) {
  secs <- as.numeric(x, units = "secs")
  if (secs < 1) paste0(round(secs * 1000), "ms")
  else if (secs < 60) paste0(round(secs, 1), "s")
  else paste0(round(secs / 60, 1), "m")
}

# Fill NAs with the last non-NA value above (like tidyr::fill, direction
# "down"). Leading NAs are kept as NA.
.fill_down <- function(x) {
  last_seen <- cummax(seq_along(x) * !is.na(x))
  c(x[NA_integer_], x)[last_seen + 1]
}

# Split each string into exactly three fields on the first two matches of
# `pattern` (like stringr::str_split_fixed(n = 3)): missing fields become "",
# anything after the second match -- including further matches -- stays in V3.
.split3 <- function(x, pattern) {
  split_once <- function(x) {
    m <- regexpr(pattern, x)
    len <- attr(m, "match.length")
    first <- ifelse(m > 0, substr(x, 1, m - 1), x)
    rest  <- ifelse(m > 0, substr(x, m + len, nchar(x)), "")
    list(first, rest)
  }
  s1 <- split_once(x)
  s2 <- split_once(s1[[2]])
  matrix(c(s1[[1]], s2[[1]], s2[[2]]), ncol = 3,
         dimnames = list(NULL, c("V1", "V2", "V3")))
}
