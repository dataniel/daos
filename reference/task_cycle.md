# Register a production cycle as a chain of steps

Adds a sequence of tasks for one statistics production, wired up so each
step depends on the one before it. The result is a ready-to-run cycle:
[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md)
reports only the first step as unblocked, and each later step becomes
ready as its predecessor is completed. A deadline (and an optional
recurrence, so the cycle's release date rolls forward) lands on the
final step.

## Usage

``` r
task_cycle(
  db,
  project,
  steps,
  keys = NULL,
  assignee = NULL,
  priority = NULL,
  due = NULL,
  recur = NULL
)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- project:

  The production this cycle belongs to.

- steps:

  Character vector of step descriptions, in order.

- keys:

  Optional character vector of keys, one per step, so the steps can be
  referenced by name from scripts.

- assignee:

  Optional person the task is assigned to.

- priority:

  Optional priority: `"H"`, `"M"`, or `"L"`.

- due:

  Optional deadline for the *final* step (the release).

- recur:

  Optional recurrence for the final step, so completing the cycle spawns
  the next release. See
  [`task_add()`](https://dataniel.github.io/daos/reference/task_add.md)
  for the cadences.

## Value

A tibble of the created tasks, in order.

## See also

[`task_step()`](https://dataniel.github.io/daos/reference/task_step.md),
[`task_require()`](https://dataniel.github.io/daos/reference/task_require.md),
[`task_add()`](https://dataniel.github.io/daos/reference/task_add.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_cycle(db, "RS-2026",
  steps = c("Hent kilder", "Validér", "Kompilér", "Publicér"),
  keys  = c("hent", "valider", "kompiler", "publicer"),
  assignee = "pipeline", due = "2026-07-15", recur = "monthly")
} # }
```
