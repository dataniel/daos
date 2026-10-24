# CPR benchmark: daos versus statgs

Measured locally on Windows 11, R 4.6.1, on 2026-10-23.
Versions and session details are in `statgs-session.txt`; raw results are
in `statgs-results.csv`.

| Task (10,000 rows) | daos seconds | statgs seconds | Ratio |
| --- | ---: | ---: | ---: |
| Age, common date | 0.0234 | 12.59 | 538x |
| Age, date per row | 0.0234 | 12.61 | 539x |
| Age, year per row (primo) | 0.0206 | 13.19 | 640x |
| Birth date | 0.0246 | 12.77 | 519x |
| All five outputs | 0.0400 | 26.39 | 660x |

These are local measurements, not universal speed guarantees. Inputs are
synthetically constructed CPR strings with valid encoded birth dates, not
records of people. The test uses 1,000 and 10,000 rows, a fixed random seed,
one warmup, and the median of three timed repetitions in alternating order.
Each daos repetition averages 50 calls to avoid timer-resolution artifacts.
Garbage collection runs before timing; collection during calls is included.
Data generation, reference-date preparation and package loading are excluded.

The private statgs `R/pnr.R` source was loaded unchanged into an isolated R
environment, without installing the rest of the package. No private source
is included here. daos includes its data-frame output overhead even in the
single-output comparisons. The all-output case calls statgs `dob`, `age`,
`gender`, and `mod11`, derives validity from nonmissing birth dates, and
sets the female code to 0 to match daos. This validity comparison applies
to this valid-format dataset; it does not establish identical handling of
malformed inputs. The separate statgs calls recompute birth dates within age.

Birth dates, sex, modulus-11 and validity agree on these inputs. Ages do not
always agree: statgs floors elapsed days divided by 365.25, while daos uses
calendar birthdays. At 10,000 rows there are 10 age differences with the
common reference date and 12 with row-specific dates. For example, someone
born on 2001-01-01 is 25 on 2026-01-01 in daos but 24 in statgs.
This boundary example was checked separately after the timed run.

To repeat from the daos root, obtain `R/pnr.R` from the statgs commit recorded
in `statgs-session.txt` using your existing private-repository access, then run:

```sh
Rscript benchmarks/benchmark-statgs.R /path/to/statgs/R/pnr.R STATGS_COMMIT
```

The script overwrites the result CSV and session file. No production code
was changed for this benchmark.


## Native CPR optimisation and clean_cpr workflow

`benchmark-cpr.R` compares the selection API before native optimisation
(`baseline-cpr-ux.R`, a frozen reference) with the current implementation.
It uses synthetic mixed-format inputs, checks exact output equality, and
measures scalar/year/date references, multiple ages, and both direct and
explicitly cleaned workflows. Build uses normal release compiler flags.

```sh
Rscript benchmarks/benchmark-cpr.R
# Or select row counts:
Rscript benchmarks/benchmark-cpr.R 1000000
Rscript benchmarks/benchmark-cpr-memory.R
```

Results are in `cpr-results.csv`, with session details in `cpr-session.txt`.
The median of three repetitions in alternating order is reported. The
1,000-row case batches 100 calls; larger cases time one call per repetition.
Input generation and the equality check are outside the timed region.
`cpr-memory.csv` reports total R allocations, not peak resident memory.
The `statgs-results.csv` measurements above are historical; they have not
been rerun for the native implementation.

`clean_cpr()` standardises identifiers for joining/export. Calling it before
`add_cpr_info()` is optional: the latter uses the same cleaning rules directly
while deriving all outputs in a single native pass, without constructing a
cleaned copy of the source. Already clean character vectors pass through
`clean_cpr()` without being copied. No cache or validation-skipping marker is
attached to data, so subsequent edits cannot leave stale validation results.

Source builds require a C compiler (Rtools on Windows); no Rcpp or additional
runtime package dependency was added. The old benchmark snapshot is excluded
from package builds with the rest of `benchmarks/`.

### Final local results: 1,000,000 rows

Median seconds, three alternating repetitions, release build on the Windows/R
system recorded in `cpr-session.txt`. Baseline is the selection API immediately
before native optimisation, not the older statgs comparison above.

| Operation | Before | After | Speedup |
| --- | ---: | ---: | ---: |
| All five standard outputs | 11.314 | 0.103 | 110x |
| Three ages, sex, and birth date | 11.140 | 0.295 | 38x |
| Age from row-specific Date references | 2.245 | 0.123 | 18x |
| Age from row-specific ISO strings | 24.087 | 0.118 | 204x |
| Explicit cleaning, then age/sex/birth date | 4.470 | 0.198 | 23x |
| Cleaning already canonical strings | 0.668 | 0.036 | 18x |

Every timed case first passed an exact output comparison. Times are local
measurements, not universal guarantees. For a separate million-row mixed-input
allocation test, all standard outputs allocated 23.5 MiB versus 1,661 MiB in
the baseline. These are total R allocations, not peak memory. Cleaning an
already canonical vector allocated no new R memory in that measurement.
