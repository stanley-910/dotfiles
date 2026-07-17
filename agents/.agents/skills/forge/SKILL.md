---
name: forge
description: Onboard to any repo's GitLab/GitHub issue tracker and work its board — list/grab/close issues, wire blocking, follow wayfinder and board-watcher conventions, and record what you grabbed so the human's hotkeys can open it. Use when asked to grab/claim/work an issue or ticket, triage or file issues, query a board or frontier, resolve wayfinder tickets, or when starting work that references an issue number in any git repo.
---

# Forge: issue-board work in any repo

## Source of truth

The GitLab board is the central issue tracker. Go straight to the bundled
`glab-board` script for tracker state and operations. Do not search for or read
repo-local tracker docs such as `docs/agents/issue-tracker.md`; they are not
authoritative. Use [REFERENCE.md](REFERENCE.md) for board conventions.

## The board script

Use `scripts/glab-board` (relative to this skill) for ALL board operations —
it derives host + project from the repo's origin remote, so it works in any
checkout or worktree. **Never hand-construct `glab api projects/<path>`
calls**: missing `GITLAB_HOST` and unencoded namespaces are where 404s come
from.

```
glab-board start <iid> [work|research] | finish <iid> [finish-options]
           | frontier | list | view <iid> | edit <iid> --description-file <path>
           | grab <iid> [work|research] | park <iid> [text]
           | note <iid> <text> | close <iid> [text]
           | block <A> <B> | mr <create-args> | triage
```

## Issue-work lifecycle — the contract

For implementation or ticket research, start with one command from the shared
checkout:

```bash
glab-board start <iid> [work|research] --json
```

`start` fetches the remote default branch, creates or resumes a deterministic
issue branch in `~/worktrees/<project>/...`, assigns and labels the issue, and
records it through `agent-link` inside that worktree. It checks the shared
checkout and warns when dirty; those local changes are deliberately excluded
because the issue worktree starts from the remote default branch. The JSON
result is the source of truth for the worktree path. Pi's session cwd is fixed: if the
watcher did not launch you in the returned worktree, use that absolute path as
`cwd` for every subsequent tool call; a shell `cd` does not move the harness.

After implementation, tests, and a normal commit, finish with one command from
the issue worktree:

```bash
glab-board finish <iid> [--description-file <path>]
```

`finish` requires a clean issue branch with commits over the remote target,
runs `.agent/verify` or `scripts/verify-agent-change` when present, pushes the
current branch, creates or reuses a ready MR, verifies
source/target/draft/change state, and records it. When the agent has a useful
summary, pass a non-empty `--description-file` containing concise change and
verification notes. Otherwise `finish` derives a `Summary` from the branch's
commit subjects and records the verification command. In both cases it ensures
a closing reference and the board-watcher marker are present without duplicating
ones already supplied; normally omit both from the file. Supplying a file also
updates an already-open MR, while a bare
retry preserves its existing description. `finish` never stages or commits
files and never pushes main. Use `--draft` only when a draft is intentional;
use `--skip-verify` only when the reason is explicit in the final reply.

`glab-board grab <iid> [work|research]` remains the lower-level claim verb for
an already-created worktree. It assigns the issue, sets `agent::working` or
`agent::researching`, and records the issue. Reading is `view`, not a claim.

Status lifecycle after that: `glab-board park <iid> [comment]` when you stop
— blocked, waiting on a human, or ending the session unfinished
(`agent::parked`); `glab-board close <iid> [comment]` clears the `agent::*`
labels. Never leave an issue labelled `agent::working` when you are no longer
working it.

`glab-board mr <create-args>` remains available for non-issue MRs. It pins the
current branch as source, refuses main/detached/empty/dirty sources, defaults
to the remote default target, pushes, verifies the resulting ready/draft state,
and records it. An explicit source branch must match the checked-out branch.

## Label discipline (board-watcher repos)

Some repos run a watcher that **dispatches agent sessions off labels**. Treat
these as live wires, not descriptions:

- `ready-for-agent` / `ready-for-research` — TRIGGER labels: applying one
  dispatches a session. Apply only when the ticket is genuinely
  agent-runnable and fully specified; re-adding one means "run it again".
- `agent::working` / `agent::researching` / `agent::parked` — status labels.
  Set them ONLY through `glab-board grab|park|close`, never by hand-editing
  labels; the watcher also reads and reconciles them.
- Terminal states retire the trigger label and add `ready-for-human` (the
  human review queue); any dispatch removes `ready-for-human`.

## Wayfinder awareness

A `wayfinder:map` issue is a shared planning map; its child tickets
(`wayfinder:research|prototype|grilling|task`) resolve one decision each.
If your issue is a wayfinder ticket: claim = assign (use `grab`), resolve
**at most one ticket per session**, post the answer as a resolution comment,
close it, and append a one-line pointer to the map's "Decisions so far".
Frontier = open + unblocked + unassigned children. Full operations, including
child-ticket creation and GraphQL frontier queries, are in
[REFERENCE.md](REFERENCE.md).

## Writing issues and comments

- Ticket bodies are structured, not prose: see the template in
  [REFERENCE.md](REFERENCE.md). A `ready-for-agent` ticket must lock scope,
  repository boundaries, decisions, edit sites, wire contracts, and success
  checks; it must not retain unresolved "Open questions". When a Details
  section supplies exact sites or precedents, read those before broad
  reconnaissance.
- Every triaged issue carries exactly one category label and one state label.
- AI-authored triage comments/bodies start with
  `> *This was generated by AI during triage.*`
- Refer to issues by **name with the id inside a link**, never bare `#42`
  runs, in anything a human reads.
- Blocking uses the tracker's native relationship (renders the frontier in
  the UI). Direction matters — see REFERENCE.md before wiring links.
