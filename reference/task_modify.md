# Modify a task

Updates the supplied fields. Pass `tags` to replace the task's tags.

## Usage

``` r
task_modify(
  db,
  id,
  description = NULL,
  key = NULL,
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

  Task identifier: the integer id, the uuid, or the key.

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
  `"monthly"`, `"quarterly"`, `"yearly"`. Needs a `due`.

## Value

`TRUE`, invisibly.

## Details

Pass `key` to set or rename the task's key; pass `key = ""` to remove
it. A new key must still be unique.
