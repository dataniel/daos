# Less fiddling with file paths

Working with files in R means dealing with paths, and on Windows that is
a small but constant annoyance. Nothing here is hard – it is just
friction: backslashes that R will not accept, a file explorer you keep
switching to and from, and the same little chores repeated every time
you point at a new file.

This is not a style guide. It is just a few small attempts to make
working with Windows paths a bit less tedious, collected as functions in
**daos**. Take whatever you find useful and ignore the rest.

## The annoyances

Three small things cause most of it:

1.  **Pasted Windows paths have backslashes**, which R reads as escape
    characters, so every path needs `\` turned into `/` before it is a
    valid string.
2.  **Finding a file means leaving R** for the file explorer, copying
    the path, and pasting it back.
3.  **It repeats.** A handful of files in one script means doing all of
    the above a handful of times.

The functions below each take one of these off your plate.

## Grab a path without typing it: `browse_files()`

[`browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md)
is a small file explorer that lives inside R. It opens a three-column,
keyboard-driven browser – parent folder, current folder, and a preview –
that you move through with `h`/`j`/`k`/`l` or the arrow keys.

``` r

p <- browse_files()    # navigate, mark with Space, press Q
```

Mark one or more files or folders with `Space`, then `Q` hands the paths
back to R – a single string for one, a `c("a", "b")` vector for several
– already with forward slashes, so there is nothing to fix. `y` copies
the same expression to the clipboard, and `o` opens the item under the
cursor in the system explorer. No second window, no clipboard
round-trip.

Press `r` to toggle *reader mode*: instead of the bare path, `Enter` and
`y` read the target with
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md).
A single file is read inline –

``` r

daos::read_files("data/x.tsv")
```

while several paths are bound to a `my_paths` object first, then read,
so the vector is named and left around to reuse:

``` r

my_paths <- c(
  "data/a.tsv",
  "data/b.csv"
)

daos::read_files(my_paths)
```

(The call is namespaced as
[`daos::read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
so the pasted line runs even when you reached the browser via
[`daos::browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md)
without attaching the package.)

The format is detected for you either way.

## Jump to a file you already have in code: `open_in_explorer()`

The other direction: you have a path in your script and want to see it
on disk.
[`open_in_explorer()`](https://dataniel.github.io/daos/reference/open_in_explorer.md)
does it from the console, and the **Open in file explorer** addin does
it from wherever the cursor is.

``` r

open_in_explorer("C:/data/2026")
open_in_explorer(my_dir)   # a variable holding a path works too
```

The addin figures out its target on its own: the selected text, or the
path-like word under the cursor (so you can just rest the cursor on a
path or an object holding one), or the working directory if there is
nothing. A literal path opens directly; anything else is evaluated as R
code; a file is revealed (selected) inside its folder rather than
opened.

## Fix the backslashes

When a path does arrive over the clipboard, three addins turn it into
valid R, depending on how it came in:

- **[`addin_paste_path()`](https://dataniel.github.io/daos/reference/addin_paste_path.md)**
  reads the clipboard, flips the backslashes, and inserts the result as
  a quoted string – the one-step “I just copied a path” move.
- **[`addin_fix_path()`](https://dataniel.github.io/daos/reference/addin_fix_path.md)**
  repairs paths already in your file: the selection, or the whole file
  if nothing is selected. It only touches real Windows paths and leaves
  `\(x)` lambdas and `\n` escapes alone.
- **[`addin_flip_backslash()`](https://dataniel.github.io/daos/reference/addin_flip_backslash.md)**
  is the blunt version: every `\` in the selection becomes `/`, for when
  that is all you want.

These are RStudio addins, like the explorer one above. I prefer to call
them from the command palette (`Ctrl+Shift+P`, then type the addin
name), but you can also bind whichever you use most to a keyboard
shortcut under *Tools -\> Modify Keyboard Shortcuts*.

## Turn a list of filenames into a vector

Filenames often arrive as a list – one per line in an email or a
spreadsheet column.
[`addin_text_to_vector()`](https://dataniel.github.io/daos/reference/addin_text_to_vector.md)
wraps a selection of lines into a `c(...)` expression, so

    jan.csv
    feb.csv
    mar.csv

becomes

``` r

c(
  "jan.csv",
  "feb.csv",
  "mar.csv"
)
```

without hand-quoting each line.

## Then read them: `read_files()`

Once the paths are in hand,
[`read_files()`](https://dataniel.github.io/daos/reference/read_files.md)
reads them – one call that expands `glue`-style patterns, checks the
files exist, detects the format, and names the results, with a progress
bar for a batch.

``` r

read_files("C:/data/2026_q{1:4}.parquet", names = 1:4)
```

[`summon()`](https://dataniel.github.io/daos/reference/summon.md) is its
companion for gathering objects you have already read back into a list
by a name pattern. The reading side – formats, custom readers, and
binding files that will not stack – has its own article,
[`vignette("read-files")`](https://dataniel.github.io/daos/articles/read-files.md).
This one is just about getting the paths right with less fuss.
