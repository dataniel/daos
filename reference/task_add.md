# Add a task

Add a task

## Usage

``` r
task_add(
  db,
  description,
  key = NULL,
  project = NULL,
  assignee = NULL,
  tags = NULL,
  priority = NULL,
  due = NULL,
  recur = NULL,
  depends = NULL
)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- description:

  The task text (required).

- key:

  Optional user-chosen handle to reference the task by – a slug of
  lowercase letters/digits joined by single `-` or `_` (e.g.
  `"compile-accounts"`). Must be unique across the database, and is
  accepted anywhere an `id` is. Lets a production script refer to a task
  by a stable, readable name instead of a brittle integer. The numeric
  `id` and `uuid` keep working regardless.

- project:

  Optional project name.

- assignee:

  Optional person the task is assigned to.

- tags:

  Optional character vector of tags.

- priority:

  Optional priority: `"H"`, `"M"`, or `"L"`.

- due:

  Optional due date (`Date` or `"YYYY-MM-DD"`).

- recur:

  Optional recurrence applied when the task is completed: an integer
  number of days, or one of `"daily"`, `"weekly"`, `"biweekly"`,
  `"monthly"`, `"quarterly"`, `"semiannual"`, `"yearly"` – the cadences
  statistics production runs on. Needs a `due`.

- depends:

  Optional ids (integer, uuid, or key) this task depends on.

## Value

The new task as a one-row tibble, invisibly.

## See also

[`task_list()`](https://dataniel.github.io/daos/reference/task_list.md),
[`task_done()`](https://dataniel.github.io/daos/reference/task_done.md)

## Examples

``` r
if (FALSE) { # \dontrun{
task_add("tasks.sqlite", "Write the report", project = "Q3",
         tags = c("writing", "urgent"), priority = "H", due = "2026-07-01")

# Give it a key, then refer to it by that key later:
task_add("tasks.sqlite", "Compile accounts", key = "compile-accounts")
task_done("tasks.sqlite", "compile-accounts")
} # }
```
