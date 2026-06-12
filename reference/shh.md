# Suppress messages and warnings

Evaluates an expression while suppressing all
[`message()`](https://rdrr.io/r/base/message.html) and
[`warning()`](https://rdrr.io/r/base/warning.html) calls. Useful when
loading packages or calling verbose functions.

## Usage

``` r
shh(expr)
```

## Arguments

- expr:

  An R expression to evaluate silently.

## Value

The return value of `expr` (unchanged).

## Examples

``` r
shh(message("this message will not appear"))
shh(warning("this warning will not appear"))

# Typical use: load packages without startup text
if (FALSE) { # \dontrun{
shh(library(tidyverse))
} # }
```
