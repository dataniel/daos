# RStudio addin: fix Windows paths

Replaces backslashes with forward slashes in Windows-style paths
(`C:\...` or `\\server\...`). Operates on the selected text, or the
entire active file if nothing is selected.

## Usage

``` r
addin_fix_path()
```
