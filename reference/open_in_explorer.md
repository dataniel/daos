# Open a path in the system file explorer

Opens a directory directly, or reveals a file (selected) inside its
containing folder. Used as the target of the directory links in cli
messages: RStudio only executes link code of the form `pkg::fun(args)`
from a loaded package, so this thin exported wrapper exists for the
internal `.path_link()` helper to point at.

## Usage

``` r
open_in_explorer(path = getwd())
```

## Arguments

- path:

  A file or directory path. Defaults to the working directory.

## Value

`path`, invisibly.
