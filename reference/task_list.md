# List tasks

Returns tasks as a tibble, with tags aggregated, an annotation count, a
`blocked` flag (a dependency is still pending), and a simplified
taskwarrior `urgency` score. Sorted by urgency by default.

## Usage

``` r
task_list(
  db,
  status = "pending",
  project = NULL,
  assignee = NULL,
  tag = NULL,
  sort = c("urgency", "due", "entry", "project"),
  desc = FALSE,
  .only_uuid = NULL
)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- status:

  Status filter: `"pending"` (default), `"completed"`, `"deleted"`,
  `"active"` (pending plus completed, i.e. everything not soft-deleted),
  or `"all"`.

- project:

  Optional project filter.

- assignee:

  Optional person filter.

- tag:

  Optional tag filter (kept if the task carries the tag).

- sort:

  One of `"urgency"` (default), `"due"` (forfaldsdato), `"entry"`
  (oprettelsesdato), or `"project"`.

- desc:

  If `TRUE`, reverse the sort order (e.g. latest due date or newest task
  first). Tasks with no due date or project stay last either way.

- .only_uuid:

  Internal: restrict to a single uuid.

## Value

A tibble of tasks.

## See also

[`task_add()`](https://dataniel.github.io/daos/reference/task_add.md),
[`task_projects()`](https://dataniel.github.io/daos/reference/task_projects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_list("tasks.sqlite")
task_list("tasks.sqlite", project = "Q3", tag = "urgent")
} # }
```
