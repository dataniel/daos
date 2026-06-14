# Add a task

Add a task

## Usage

``` r
task_add(
  db,
  description,
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
  `"monthly"`, `"quarterly"`, `"yearly"`. Needs a `due`.

- depends:

  Optional ids (integer or uuid) this task depends on.

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
} # }
```
