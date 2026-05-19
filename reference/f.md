# String interpolation shorthand

A short alias for
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html).
Interpolates R expressions enclosed in
[`{}`](https://rdrr.io/r/base/Paren.html) inside a string. All arguments
accepted by
[`glue::glue()`](https://glue.tidyverse.org/reference/glue.html) are
forwarded.

## Usage

``` r
f(
  ...,
  .sep = "",
  .envir = parent.frame(),
  .open = "{",
  .close = "}",
  .na = "NA",
  .null = character(),
  .comment = "#",
  .literal = FALSE,
  .transformer = identity_transformer,
  .trim = TRUE
)
```

## Arguments

- ...:

  \[`expressions`\]  
  Unnamed arguments are taken to be expression string(s) to format.
  Multiple inputs are concatenated together before formatting. Named
  arguments are taken to be temporary variables available for
  substitution.

  For `glue_data()`, elements in `...` override the values in `.x`.

- .sep:

  \[`character(1)`: ‘""’\]  
  Separator used to separate elements.

- .envir:

  \[`environment`:
  [`parent.frame()`](https://rdrr.io/r/base/sys.parent.html)\]  
  Environment to evaluate each expression in. Expressions are evaluated
  from left to right. If `.x` is an environment, the expressions are
  evaluated in that environment and `.envir` is ignored. If `NULL` is
  passed, it is equivalent to
  [`emptyenv()`](https://rdrr.io/r/base/environment.html).

- .open:

  \[`character(1)`: ‘\\’\]  
  The opening delimiter. Doubling the full delimiter escapes it.

- .close:

  \[`character(1)`: ‘\\’\]  
  The closing delimiter. Doubling the full delimiter escapes it.

- .na:

  \[`character(1)`: ‘NA’\]  
  Value to replace `NA` values with. If `NULL` missing values are
  propagated, that is an `NA` result will cause `NA` output. Otherwise
  the value is replaced by the value of `.na`.

- .null:

  \[`character(1)`: ‘character()’\]  
  Value to replace NULL values with. If
  [`character()`](https://rdrr.io/r/base/character.html) whole output is
  [`character()`](https://rdrr.io/r/base/character.html). If `NULL` all
  NULL values are dropped (as in
  [`paste0()`](https://rdrr.io/r/base/paste.html)). Otherwise the value
  is replaced by the value of `.null`.

- .comment:

  \[`character(1)`: ‘#’\]  
  Value to use as the comment character.

- .literal:

  \[`boolean(1)`: ‘FALSE’\]  
  Whether to treat single or double quotes, backticks, and comments as
  regular characters (vs. as syntactic elements), when parsing the
  expression string. Setting `.literal = TRUE` probably only makes sense
  in combination with a custom `.transformer`, as is the case with
  `glue_col()`. Regard this argument (especially, its name) as
  experimental.

- .transformer:

  \[`function`\]  
  A function taking two arguments, `text` and `envir`, where `text` is
  the unparsed string inside the glue block and `envir` is the execution
  environment. A `.transformer` lets you modify a glue block before,
  during, or after evaluation, allowing you to create your own custom
  `glue()`-like functions. See `vignette("transformers")` for examples.

- .trim:

  \[`logical(1)`: ‘TRUE’\]  
  Whether to trim the input template with
  [`trim()`](https://glue.tidyverse.org/reference/trim.html) or not.

## Value

A character vector of interpolated strings.

## See also

[`nowf()`](https://dataniel.github.io/daos/reference/nowf.md)

## Examples

``` r
f("2 + 2 = {2 + 2}")
#> 2 + 2 = 4
name <- "world"
f("Hello, {name}!")
#> Hello, world!

# Combine with nowf() for timestamped paths:
if (FALSE) { # \dontrun{
f("data/export_{nowf('%Y%m%d')}.parquet")
f("log/{nowf()}/0-check.log")
} # }
```
