# Track the last data frame printed in the console

Installs a task callback that automatically saves any data frame
returned to the console as a named variable in the global environment.
Intermediate expressions (`1 + 1`, plots, etc.) are ignored — only
top-level data frame returns are captured.

## Usage

``` r
track_last_df(on = TRUE, name = ".last.df")
```

## Arguments

- on:

  `TRUE` to enable tracking (default), `FALSE` to disable.

- name:

  Name of the variable written in `.GlobalEnv`. Default: `".last.df"`.

## Value

`TRUE` invisibly.

## Details

Calling `track_last_df()` again replaces any existing callback,
preventing duplicates.

## Examples

``` r
if (FALSE) { # \dontrun{
track_last_df()          # enable
dplyr::starwars |> head()
.last.df                 # the last printed data frame

track_last_df(FALSE)     # disable
} # }
```
