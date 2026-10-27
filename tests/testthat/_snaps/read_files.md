# read_files() rejects a name on a pattern that expands to several files

    Code
      read_files(c(a = "f{1:2}.csv"))
    Condition
      Error in `read_files()`:
      ! A name in `paths` must belong to a single file.
      x "a" expands to several files.
      i Name the files with `names` instead.

# read_files() warns when files share a name, and refuses to unpack them

    Code
      result <- read_files(c("a/data.csv", "b/data.csv"))
    Condition
      Warning:
      Several files share the name "data", so they cannot be told apart in the result.
      i Name them apart with `names`.

---

    Code
      read_files(c("a/data.csv", "b/data.csv"), out = "unpack", .envir = env)
    Condition
      Error in `read_files()`:
      ! Several files would be unpacked to the same name: "data".
      i Name them apart with `names`.

# read_files() lists missing files with their full path, capped at ten

    Code
      read_files("no/such/dir/f{1:12}.csv")
    Condition
      Error in `read_files()`:
      ! 12 of 12 files could not be found:
      x no/such/dir/f1.csv
      x no/such/dir/f2.csv
      x no/such/dir/f3.csv
      x no/such/dir/f4.csv
      x no/such/dir/f5.csv
      x no/such/dir/f6.csv
      x no/such/dir/f7.csv
      x no/such/dir/f8.csv
      x no/such/dir/f9.csv
      x no/such/dir/f10.csv
        ... and 2 more

# read_files() reads every file and reports all failures together

    Code
      read_files(c("x.json", "ok.json", "y.json"))
    Condition
      Error in `read_files()`:
      ! Could not read 2 of 3 files:
      x x.json: lexical error: invalid char in json text.
      x y.json: lexical error: invalid char in json text.

# read_files() aborts on unsupported extension before reading anything

    Code
      read_files(c("b.csv", "a.xyz"))
    Condition
      Error in `read_files()`:
      ! No reader for .xyz files.
      i Supported: csv, tsv, txt, rds, xlsx, xls, parquet, feather, sas7bdat, sav, por, xpt, dta, json, ndjson, jsonl, yaml, and yml.
      i Use `reader` to supply a custom reader function.

# read_files(out = 'bind') re-types only the conflicting columns

    Code
      result <- read_files(c("a.rds", "b.rds"), out = "bind", .id = "f")
    Condition
      Warning:
      Column types differ across files for x -- re-typed with `readr::parse_guess()`.
      i Use `daos::view_types()` to inspect the differences.

# read_files(out = 'bind') names the files that are not data frames

    Code
      read_files(c("a.txt", "b.csv"), out = "bind")
    Condition
      Error in `read_files()`:
      ! `out = "bind"` needs data frames, but 1 file did not read as one:
      x a.txt: <character>

# read_files() reports all multi-sheet workbooks in one warning

    Code
      result <- read_files(c("a.xlsx", "b.xlsx", "c.xlsx"))
    Condition
      Warning:
      2 workbooks have more than one sheet; only the first was read.
      * a.xlsx: also "Two"
      * b.xlsx: also "B", "C"
      i Read another sheet with `sheet = "..."`, which is passed on to the reader.

