# Forge platform-agnostic scoping (GitHub + GitLab + Jira)

Status: design scoping, 2026-07-18. Not yet implemented.

## Story

> Agent lands in an EA repo. Origin is GitHub Enterprise; the board is Jira.
> `glab-board list` → dies ("glab not installed" or 404s against the wrong host).
> Agent hand-rolls `gh` + Jira REST calls, gets the label names wrong,
> board-watcher never sees the status change, the MR closes nothing.

## Why

The current script assumes the issue tracker IS the git remote. GitHub/GitLab
colocate them; Jira splits them. Everything else — labels, IDs, closing
keywords, blocking links — hangs off that broken assumption. Meanwhile four
other consumers (board-watcher, /triage, /to-tickets, /wayfinder) depend not
on the script but on its *contracts*: the verb interface, the `start --json`
schema, the label vocabulary, and the MR marker. The design must change the
implementation while freezing those contracts.

## Decision sketch

1. **Two axes, not one.** `forge` (where MRs/PRs go — derived from origin
   remote, overridable) and `tracker` (where the board lives — gitlab |
   github | jira, defaults to the forge). Every verb decomposes into tracker
   ops + forge ops; only `start`/`finish`/`mr` touch the forge.
2. **Dispatcher + adapters, still bash + official CLIs.** `scripts/board`
   keeps all platform-neutral logic (worktrees, branch naming, verify,
   description building, marker, agent-link). Per-platform scripts implement
   a fixed sub-verb contract: `tracker-gitlab`, `tracker-github`,
   `tracker-jira` (via `jira-cli`), `forge-gitlab`, `forge-github`.
   `glab-board` stays as a compat symlink — board-watcher calls it by path.
3. **Per-project config, written by `/forge init`.** Resolution order:
   repo `.forge/config.toml` (team-shared) → `~/.config/forge/<host>/<path>.toml`
   (personal; also holds overrides). Guided interview: detect remote →
   confirm forge kind → "tracker = forge or Jira?" → Jira site/key/auth →
   state-mapping choice → offer label bootstrap → smoke test.
4. **Abstract state model.** The REFERENCE.md label vocabulary becomes the
   abstraction; config maps each abstract state to a platform token
   (GitLab scoped labels / GitHub plain labels / Jira labels *or* workflow
   statuses — per-project choice, because Jira admins differ).
5. **Formalize the contracts in a versioned CONTRACT.md** cited by both
   forge and board-watcher: verb interface, `start --json` schema, label
   vocabulary, marker v2
   (`<!-- board-watcher: v=2 tracker=jira source_project=GAME source_issue=GAME-123 conversation_key=… -->`,
   old fields kept on GitLab for back-compat).
6. **Board-watcher phases later, independently.** Contracts frozen ⇒ it keeps
   working GitLab-only while the skill goes agnostic. Its multi-platform lift
   (extract a client protocol, per-platform polling) is its own project.

## Config schema (draft)

```toml
schema = 1

[forge]                      # usually derived; override for enterprise hosts
kind = "github"              # gitlab | github

[tracker]
kind = "jira"                # gitlab | github | jira   (default: forge.kind)
site = "ea.atlassian.net"    # jira only
project = "GAME"             # jira project key

[states]                     # abstract state -> platform token
scheme = "labels"            # labels | jira-status
working = "agent::working"   # jira-status example: working = "In Progress"
researching = "agent::researching"
parked = "agent::parked"
trigger_work = "ready-for-agent"
trigger_research = "ready-for-research"
human = "ready-for-human"

[workflow]
branch_format = "{id}-{slug}"   # default "issue-{id}-{slug}"; Jira: "{KEY}-{slug}"
verify = ".agent/verify"
worktree_root = "~/worktrees"
```

## Jira gotchas (why tracker-jira is the hard adapter)

- IDs are `KEY-123`, not numeric — verb args, branch naming, and finish's
  `issue-$iid-*` branch guard all become format-driven.
- `Closes #N` in an MR body closes nothing. Jira linkage = issue key in
  branch/MR title (smart-commit autolink) + a remote-link posted by the
  tracker adapter at finish. Closing stays a tracker-adapter verb, as today.
- No label-add event stream, but status/column triggers poll *better* than
  GitLab labels: one JQL query
  (`status CHANGED TO "Ready for Agent" AFTER -5m`) returns column entries
  server-side; dedupe on changelog entry ids. JQL `CHANGED` does not support
  the labels field — another reason triggers map to statuses on Jira.
  Webhooks are true push but need a reachable endpoint (server-scale
  upgrade path, not v1); Atlassian's MCP server is request/response only,
  no board events.
- Jira labels forbid spaces; whether `agent::working` survives as a label is
  per-instance — `/forge init` should create-and-verify, and fall back to
  `agent-working` or status mapping.
- Blocking: native "is blocked by" links exist; frontier needs per-issue link
  inspection (no cheap `blocked` boolean like GitLab).
- Wayfinder mapping: map → Epic, children → issues-in-epic (natural fit,
  better than GitLab's Task workaround).

## Phasing (revised 2026-07-18: Jira backlogged)

Decision: Jira is deferred until there's a real Jira board to serve. With it
out of v1, the dispatcher/adapter refactor loses its near-term justification —
the tested two-platform `if` split stays, and the immediate work is GitHub
verb parity **in place**. EA GitLab is `gitlab.ea.com` (default branch of the
host sniff), GitHub work is github.com, so the Enterprise-sniff fix also
waits.

1. **GitHub verb parity in `glab-board` (now)**: `park`/`close` must clear
   `agent::*` labels as GitLab does; `block` via native issue dependencies
   (GA Aug 2025; `gh` ≥ 2.94.0 has `--add-blocked-by` and `blockedBy`
   JSON fields); `frontier` filters open blockers, matching GitLab
   semantics; `grab` label bootstrap uses REFERENCE.md colors.
2. **Backlog — `/forge init` + config resolution** (unblocks GH Enterprise
   hosts and per-project prefs; interview design above stands).
3. **Backlog — dispatcher/adapter refactor + CONTRACT.md** (do it as the
   first commit of the Jira phase, not before).
4. **Backlog — tracker-jira** (JQL `status CHANGED TO` polling design above).
5. **Backlog — board-watcher multi-platform** (own repo, biggest lift).

<details>
<summary>Agent detail — contract touchpoints and edit sites</summary>

- Verb interface consumers: board-watcher `watcher.py:2776-2828` (calls
  `~/.agents/skills/forge/scripts/glab-board start <iid> [mode] --json` with
  `cwd=local_checkout`, parses `{worktree, branch}`); keep path + JSON shape.
- `start --json` schema: `{issue, worktree, branch, base, issue_url}`
  (`glab-board:170-186`). Extend `issue` to string for Jira keys — check
  board-watcher's parse for int coercion before shipping.
- Marker: emitted at `glab-board:354` (`write_mr_description`) and
  `watcher.py:2905-2908`; parsed by `MR_MARKER_RE`/`MR_MARKER_FIELD_RE`
  (`watcher.py:65-66`). Field-wise regex — verify unknown-field tolerance
  before adding `v=2 tracker=… source_issue=…`.
- Label writes in board-watcher go through one function
  (`set_issue_labels`, `watcher.py:2974-2981`, 4 call sites) — its future
  abstraction point.
- Branch guard to make format-driven: `glab-board:395`
  (`[[ "$branch" == issue-"$iid"-* ]]`).
- Host sniff to replace with config: `glab-board:36-37`.
- Skills coupled only via label vocabulary (no script calls): triage,
  to-tickets, to-spec, wayfinder. /orchestrate has no glab-board references;
  /workflows agents shell out to the same verbs.
- Jira CLI candidates: `ankitpokhrel/jira-cli` (mature, brew) vs Atlassian
  `acli` (official, newer). Init installs/auths either.
</details>
