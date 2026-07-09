# Global agent instructions

## Record forge links (agent-link)

When you grab an issue or open a merge/pull request during a session, record it
immediately so Stanley's tmux hotkeys can open it from the pane:

    agent-link issue <url>       # the issue you grabbed (replaces)
    agent-link mr <url>          # the MR/PR you opened (replaces)
    agent-link add mr <url>      # additional MRs in the same session

Run it from inside your worktree — it stores per-worktree metadata and tags the
tmux pane, so it must execute with the worktree as cwd. Re-run to update; it is
idempotent. `agent-link status` shows what's recorded. If the command is
missing, skip silently — do not install anything.
