# Global agent instructions

## Working style

Be direct. No pretty language. No praise. No filler. Use terse bullets. State uncertainty plainly.

## Worktree taxonomy

When creating isolated worktrees, match Stanley's Claude-agent convention.

Use persistent worktrees under:

```text
~/worktrees/<project-name>/<run-slug>/integration
~/worktrees/<project-name>/<run-slug>/<slice-id>
```

Rules:

- `<project-name>` = basename of the git root.
- `<run-slug>` = `YYYY-MM-DD_<short-slug>`.
- For orchestrated/multi-slice work, use:
  - integration path: `~/worktrees/<project>/<run-slug>/integration`
  - slice paths: `~/worktrees/<project>/<run-slug>/<slice-id>`
  - branches: `orchestrate/<run-slug>/integration` and `orchestrate/<run-slug>/<slice-id>`
- For single-ticket work that still needs isolation, use the same date+slug shape, with a meaningful branch prefix from repo convention when one exists (`fix/`, `feat/`, `chore/`, etc.).
- Do not edit the source repo from an isolated run unless explicitly asked.
- Do not delete worktrees at the end. Report paths and ask before cleanup.
- Pass absolute worktree paths into delegated agents. The worker should run all commands from its assigned worktree.
- Prefer explicit `git worktree add ...` commands over harness-owned ephemeral worktrees when the result needs inspection, integration, or follow-up.

Example:

```text
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/integration
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/a1-canonical-plan-policy
```

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

## Log papercuts

Hit a small friction — dead-end tool call, broken link, confusing setup step,
flaky command, misleading error, non-obvious gotcha? Log it in the moment:

    papercut "<what got in the way>"        # one or two sentences
    papercut -m <model> "<...>"             # attribute to your model

Writes a checkbox entry to `PAPERCUTS.md` at the repo root (`-g` for the global
file). None of these block you; logged together they show where the repo needs
sanding down. Distinct from a work log and from tracked bugs. If the command is
missing, skip silently — do not install anything.
