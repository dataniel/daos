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
  .only_uuid = NULL
)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- status:

  Status filter: `"pending"` (default), `"completed"`, `"deleted"`, or
  `"all"`.

- project:

  Optional project filter.

- assignee:

  Optional person filter.

- tag:

  Optional tag filter (kept if the task carries the tag).

- sort:

  One of `"urgency"` (default), `"due"`, `"entry"`, `"project"`.

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
