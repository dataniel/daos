# Modify a task

Updates the supplied fields. Pass `tags` to replace the task's tags.

## Usage

``` r
task_modify(
  db,
  id,
  description = NULL,
  project = NULL,
  assignee = NULL,
  tags = NULL,
  priority = NULL,
  due = NULL,
  recur = NULL
)
```

## Arguments

- db:

  Path to the task database, or an open DBI connection.

- id:

  Task id (integer) or uuid.

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

## Value

`TRUE`, invisibly.
