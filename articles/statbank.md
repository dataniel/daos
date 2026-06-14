# Browsing a statbank by keyboard

[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
is not really meant as a finished product. It is a take on a question:
what would it feel like to move through a statistics bank the way you
move through a filesystem in a terminal – by keyboard, fast, and with
the program telling you what exists at each step instead of making you
know it in advance? The `statbank_*` client underneath is a plain API
wrapper; the app is the argument that navigation could be nicer than a
tree of dropdowns.

This article is about that argument – what the app does today, and where
the idea is pointing.

## The problem with picking from a statbank

A statbank table is a set of variables, each with its own list of
values, and a table is fetched by choosing some values from each. The
standard web interface presents this as nested menus: open a folder,
open a table, then a wall of multi-selects. It works, but it asks you to
already know what you are looking for. You pick current prices without
the interface ever hinting that the table also offers chained values, an
index, or a share – the very options that might be the one you actually
want. The information you need to choose well is exactly the information
the menu does not surface while you choose.

## What the app does now

[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
is built around being shown what exists as you go.

``` r

statbank_app()           # Greenland (default)
statbank_app(bank = "fo") # the Faroe Islands
```

**Finding a table** happens in a three-column, yazi-style browser –
parent folder, current folder, and a live preview of whatever the cursor
is on – the same browser as
[`browse_files()`](https://dataniel.github.io/daos/reference/browse_files.md).
You walk the subject tree with `h`/`j`/`k`/`l` or the arrow keys, and
the preview column tells you what a folder contains or what a table is
before you commit to opening it. Or you search the titles and jump
straight there. The bank chooser sits one level *above* the subject
root, so pressing `h` at the top switches between Greenland and the
Faroe Islands – a bank is just the parent of everything else.

**Choosing values** adapts to the variable. Time, and numeric variables
with many values such as age, get from/to dropdowns. Everything else
opens a popup with a searchable checkbox list, select/deselect-all, and
a running count, so a variable with two hundred municipalities is
browsable instead of overwhelming. An empty selection means all values,
which keeps the common case to zero clicks.

**Fetching** shows the data as a table and a plot, lets you download a
formatted Excel file, and – the part that matters most – always shows
the
[`statbank_get()`](https://dataniel.github.io/daos/reference/statbank_get.md)
call that reproduces exactly what you selected. The app is a bridge from
clicking to scripting: you explore by hand once, copy the query, and
from then on it runs headless.

``` r

# the kind of call the code tab hands you
statbank_get(
  "NR/NR01/NRXxxx.PX",
  tid   = c(2023, 2024, 2025),
  enhed = "Kædede værdier"
)
```

Pressing `Q` closes the app and returns the last fetched dataset, so
`df <- statbank_app()` is itself a way to get data into R.

## Guidance is already half the point

Notice how much of the above is the program telling you what is there.
The preview column tells you what a folder holds. The popup’s running
count tells you how big your selection is. The code tab tells you what
query you just built, in a form you can keep. None of that is data you
had to bring; the app surfaces it at the moment you need it. That is the
thread worth pulling on.

## Where this is heading: guidance on what a choice *means*

Today the app guides you on *what values exist*. The more interesting
step is guidance on *what those values mean* – and that part does not
exist yet, in this app or in the official interface.

Take a value that can be shown in current prices or as chained values.
The choice is not cosmetic: if you want the volume development over time
– real growth, with price changes stripped out – you want chained
values, and a newcomer has no way to know that from a label reading
`Løbende priser` versus `Kædede værdier`. The knowledge exists – it is
in the methodology, in colleagues’ heads – but never next to the
checkbox where the decision is actually made.

The direction
[`statbank_app()`](https://dataniel.github.io/daos/reference/statbank_app.md)
is sketching is to put it there. Imagine the value popup carrying a line
of plain-language help per option:

> **Chained values (kædede værdier)** – pick this for volume
> development: real growth over time, with price changes stripped out.
>
> **Current prices (løbende priser)** – pick this for the nominal size
> in a given year, price changes included.

So you are met with the relevant guidance while you browse, not after
you have downloaded the wrong series and noticed it does not behave. The
same idea generalises: a “what is this and when do I want it” note
attached to the variables and values where the choice is genuinely
consequential.

This is not implemented. It is the reason the app is framed as a proof
of concept rather than a tool: the navigation, the previews, and the
code tab are there to show that a statbank *could* guide you through a
selection, and the value-level guidance is the next thing that idea asks
for.

## Using the client directly

If you already know the table and the values, you do not need the app at
all. The client is small and scriptable, and the app only ever produces
calls to it:

``` r

statbank_search("national accounts")

meta <- statbank_meta("NR/NR01/NRXxxx.PX")
meta$variables          # what the app would show you in the popups

df <- statbank_get(
  "NR/NR01/NRXxxx.PX",
  tid   = 2015:2024,
  enhed = "Kædede værdier"
)
```

Selections are matched against both codes and their display texts, and
Danish letters fold (`foedested` matches `fødested`), so you can write
what you see. The full client walkthrough is in
[`vignette("daos")`](https://dataniel.github.io/daos/articles/daos.md)
under `statbank_*`.
