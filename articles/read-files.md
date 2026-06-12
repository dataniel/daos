# Reading many files at once

A surprisingly large share of production scripts starts the same way:
one `read_*()` call per file.

``` r

dat2020 <- read_parquet("data/dat2020.parquet")
dat2021 <- read_parquet("data/dat2021.parquet")
dat2022 <- read_parquet("data/dat2022.parquet")
dat2023 <- read_parquet("data/dat2023.parquet")

df <- bind_rows(dat2020, dat2021, dat2022, dat2023)
```

Reading files one by one can go well, and it can go quietly wrong. The
block grows with every new delivery, the calls drift apart as one of
them picks up an extra argument, a missing file is only discovered when
its own line runs, and
[`bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html) at
the end either fails or, worse, succeeds while hiding a type change.
This article is about replacing the block with one
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
call, and about using
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
when the files turn out not to be as stackable as they looked.

## One call, many files

[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
expands paths with glue syntax, checks that *every* file exists before
reading anything, detects the format from the extension, and returns a
named list (with a progress bar along the way):

``` r

lst <- read_files("data/dat{2020:2023}.parquet", names = 2020:2023)
```

Two things are easy to miss but matter in practice:

- **Missing files fail fast and together.** One error lists every absent
  file up front, instead of the loop dying at file seven after five
  minutes of reading.
- **Column names are lowercased by default**, which removes the most
  common cosmetic difference between deliveries before it becomes a
  problem (`.lowercase = FALSE` to opt out).

## Stacking files that belong together

When the files are slices of the same dataset (years, regions, batches),
bind them directly with `out = "bind"`, and use `.id` to keep track of
where each row came from:

``` r

df <- read_files(
  "data/dat{2020:2023}.parquet",
  names = 2020:2023,
  out   = "bind",
  .id   = "year"
)
```

## When the stack does not stack

Files that *should* be identical often are not: the same column arrives
as `chr` in one year and `dbl` in the next, or a column was renamed
upstream. With the one-call-per-file pattern this surfaces, if at all,
as a confusing
[`bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
error or a silently mistyped column.

`read_files(out = "bind")` handles it instead. If the files cannot be
bound as-is, it warns, coerces everything to character, re-types the
result with
[`readr::type_convert()`](https://readr.tidyverse.org/reference/type_convert.html),
and points you to
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md):

    Warning: Column types differ across files -- coercing to character and
    re-typing with `readr::type_convert()`.
    i Use `daos::view_types` to inspect the differences.

The rule of thumb: if
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
handles a set of files without warnings, the data production is
consistent. When it warns, something changed upstream, and the next step
is to find out what.

## Finding the culprit with `view_types()`

[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
is [`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) across
multiple data frames at once: one row per column, one column per
dataset, with abbreviated type strings.

``` r

dat2023 <- tibble(cvr = "11111111", name = "Firm A", amount = 100,    year = 2023L)
dat2024 <- tibble(cvr = 11111111,  name = "Firm B", amount = "1.000", turnover = 200)

view_types(dat2023, dat2024)
#> # A tibble: 5 × 3
#>   column   dat2023 dat2024
#>   <chr>    <chr>   <chr>  
#> 1 cvr      chr     dbl    
#> 2 name     chr     chr    
#> 3 amount   dbl     chr    
#> 4 year     int     NA     
#> 5 turnover NA      dbl
```

The full listing already tells the story, but `diff = TRUE` cuts it down
to the columns that actually disagree:

``` r

view_types(dat2023, dat2024, diff = TRUE)
#> # A tibble: 4 × 3
#>   column   dat2023 dat2024
#>   <chr>    <chr>   <chr>  
#> 1 cvr      chr     dbl    
#> 2 amount   dbl     chr    
#> 3 year     int     NA     
#> 4 turnover NA      dbl
```

Read the output like this:

- A row with two different type strings (`chr` vs `dbl` for `cvr`) is a
  type mismatch, the classic cause of a failed bind or a corrupted join
  key.
- An `NA` means the column does not exist in that dataset at all (`year`
  vs `turnover` above), typically a rename or a dropped column upstream.

The same overview is just as useful *before a join*: two frames that are
about to be joined on `cvr` should agree on its type, and
[`view_types()`](https://dataniel.github.io/daos/reference/view_types.md)
answers that in one line instead of two
[`glimpse()`](https://pillar.r-lib.org/reference/glimpse.html) calls and
a visual diff.

For pipelines, the `focus` argument turns the inspection into a check:
it returns only the datasets where a critical column does *not* have the
expected type, and an empty result on success. That plugs straight into
the checkpoint pattern from
[`vignette("validation")`](https://dataniel.github.io/daos/articles/validation.md):

``` r

view_types(dat2023, dat2024, focus = c(amount = "dbl")) |>
  expect_empty(warn_msg = "amount is not numeric everywhere")
#> Warning: amount is not numeric everywhere
```

## Other shapes of output

Not every set of files should be stacked. The default (a named list)
pairs well with [`lapply()`](https://rdrr.io/r/base/lapply.html) or
[`purrr::map()`](https://purrr.tidyverse.org/reference/map.html), and
`out = "unpack"` assigns each file as its own variable. That is closest
to the one-call-per-file pattern, but with the validation, naming, and
progress handled for you:

``` r

read_files("data/dat{2020:2023}.parquet",
           names = paste0("dat", 2020:2023), out = "unpack")
```

`summon("^dat\\d+$")` collects an unpacked family back into a named list
when you change your mind.
