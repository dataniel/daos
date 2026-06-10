format_elapsed <- function(x) {
  secs <- as.numeric(x, units = "secs")
  if (secs < 1) paste0(round(secs * 1000), "ms")
  else if (secs < 60) paste0(round(secs, 1), "s")
  else paste0(round(secs / 60, 1), "m")
}

# Hyperlink a path for cli messages: displays `text` (the path as given by
# default), but links to the absolute path so the link resolves regardless of
# the working directory. RStudio's console only opens file:// links in the
# editor (directories fail silently), so directories become run-links there,
# opening the folder in the file explorer instead. The run-link code must be
# `pkg::fun(args)` from a loaded package -- RStudio refuses anything else,
# including `:::` -- hence the exported open_in_explorer() wrapper. Falls
# back to plain text in terminals without hyperlink support.
.path_link <- function(path, text = path) {
  abs <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (dir.exists(path) && Sys.getenv("RSTUDIO") == "1")
    return(cli::format_inline("{.run [{text}](daos::open_in_explorer('{abs}'))}"))
  cli::style_hyperlink(text, paste0("file://", abs))
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
