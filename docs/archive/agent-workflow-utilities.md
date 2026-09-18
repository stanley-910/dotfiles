# Optional agent workflow utilities

Archived from global instructions on 2026-09-18. This is a reference, not an
automatically loaded workflow. Use these utilities when requested.

## Forge links

`agent-link` records issue and PR/MR URLs for tmux hotkeys. Run from the relevant
worktree because metadata is scoped to it and its tmux pane.

```sh
agent-link issue <url>   # Set the current issue
agent-link mr <url>      # Set the current PR/MR
agent-link add mr <url>  # Add another PR/MR
agent-link status
```

Repeated registration is safe. Skip if unavailable; installing it is a separate task.

## Papercut records

When asked to record a workflow problem, describe the task, the blocker, and any
useful workaround in one or two sentences. Avoid logging routine retries or
mistakes without a reusable lesson.

```sh
papercut "<problem and workaround>"
papercut "<problem and workaround>" -m <model>
papercut -g "<problem and workaround>"
```

The default destination is repository-root `PAPERCUTS.md`; `-g` selects the global
record. These records describe friction, not completed work or a replacement for
an issue tracker. Skip if unavailable.
