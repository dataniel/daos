# RStudio addin: open path in file explorer

Opens a location in the system file explorer. The target is resolved to
a path in this order:

- the selected text, if any;

- otherwise the path-like token under the cursor (so you can just place
  the cursor on a path or an object holding one, no selection needed);

- otherwise the current working directory
  ([`getwd()`](https://rdrr.io/r/base/getwd.html)).

An existing literal path is used as-is; anything else is evaluated as R
code (e.g. an object or call that returns a path). A resolved file is
revealed inside its containing folder; a directory is opened directly.

## Usage

``` r
addin_open_in_explorer()
```
