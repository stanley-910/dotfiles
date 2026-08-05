# Global preferences

## Working with Stanley

- **Teaching/grilling style**: one question per turn, always with a recommendation.
  Feynman-simple — concrete mini-examples and short transcripts over abstraction.
  No filler, no fancy prose. Caveman mode only when explicitly invoked. Stanley's
  side-questions ("is dismiss a tool or a callback?") are evidence requests, not
  rhetorical — grep/verify before answering, and reverse your recommendation when
  the evidence says so.
- **Diagrams as we design**: maintain one growing mermaid class diagram per design
  effort (extend it each resolved decision) plus a sequence diagram for each
  behavioral flow. Code block in chat is enough. Never use `<br/>` in mermaid —
  Stanley pastes into Excalidraw, which doesn't render HTML breaks.
- **Ops hygiene**: verify VPN/connectivity before detaching subagents that need
  internal hosts (gitlab.ea.com). Resume a stalled subagent via SendMessage —
  don't relaunch and lose its context.
- **RTK is a compactor, not a corruptor**: rtk (@RTK.md) deliberately summarizes
  tool output to save tokens — dropped words and `N matches` rollups are the
  feature. Its summaries are for *reading*; never *parse* them. When you need
  exact/lossless bytes (JSON to `json.loads`, precise pass/fail counts,
  transcript-JSONL fidelity), bypass compaction: `rtk proxy <cmd>`, or redirect
  to a file and Read it.
- **Generated artifacts** (reports, briefs): write to durable paths (repo docs/,
  ~/.claude, or an agreed workspace) — never macOS `/var/folders` temp dirs;
  they purge within a day.
- **Citing past decisions**: state the rule in words; the record number is only a
  trailing breadcrumb — "checkout codes are never re-minted (ADR-0021)". The
  sentence must stand alone if the number is deleted. Never a bare "per ADR-0021"
  in chat, comments, or code.
- **Issue/comment skeleton** (issues, resolution comments, MR descriptions), in
  strict order: (1) **Story** — 3–6 line mini-transcript showing the problem as
  lived experience (can't write it → don't understand the problem yet);
  (2) **Why** — ≤5 plain-English sentences; (3) **Decision/fix** — ≤7 bullets;
  (4) **Agent detail** — file:line refs, payload shapes, edge cases — folded in a
  `<details>` block at the bottom.
- **Prose budget**: the human layer (1–3) must fit one screen unscrolled. At most
  one code snippet above the fold, ≤5 lines, illustrative only. One diagram
  allowed and encouraged. Everything else: fold it or cut it.

## Commits

- Never add `Co-Authored-By: Claude ...` trailers to commit messages. No Claude attribution in git history, in any project. The commit message should end with the body — no attribution footer.

@RTK.md

## Record forge links (agent-link)

When you grab an issue or open a merge/pull request during a session, record it
so tmux hotkeys can open it from the pane: `agent-link issue <url>` /
`agent-link mr <url>` (`agent-link add mr <url>` for more). Run from inside
your worktree — it stores per-worktree metadata and tags the tmux pane. If the
command is missing, skip silently.

## Log papercuts

When you hit a small friction while working — a dead-end tool call, a broken
link, a confusing or undocumented setup step, a flaky command, a misleading
error, a non-obvious gotcha — log it: `papercut "<what got in the way>"`. One
or two sentences: what you were doing → what blocked you (a guess at the
cause/fix is a bonus). Do it in the moment, even though none of these block
you — logged together they show where the repo needs sanding down. Add
`-m <model>` to attribute it. Writes to `PAPERCUTS.md` at the repo root (`-g`
for the global file). Distinct from a work log (what you accomplished) and from
tracked bugs. If the command is missing, skip silently.

## Fable-5-first delegation

Driver is Fable 5. It orchestrates — plans, decomposes, dispatches, verifies,
integrates, synthesizes. It does not run token-heavy or parallel work itself.
Once a spec is pinned, the driver must NOT hand-write well-outlined
implementation code inline — route code-writing to the fleet or a cheap Claude
subagent and keep only spec-authoring, verification, and integration inline.
This applies mid-flow: if you catch yourself writing modules after the design is
settled, stop and delegate.

Native Claude workflows stay available — use the Agent tool with Claude models
whenever the work genuinely needs Claude. Separately, offload token-heavy or
parallelizable work to the flat-rate enterprise Copilot fleet via the Pi
harness. Two ways to reach it:

1. Direct — driver shells out (its context absorbs the transcript):
   `pi -p --provider headroom-copilot --model <id>:<thinking> "<handoff>"`
   Always headroom-copilot; direct github-copilot is fallback-only (proxy
   down) — parallel direct launches race on Copilot token exchange.
2. Token-saving via a Claude workflow — when you want the Agent tool's
   parallel/background orchestration but the reasoning cost to land on the
   flat-rate fleet, launch a cheap `sonnet` (low) wrapper subagent that does no
   reasoning itself: it `exec`s the `pi` command above, waits, and returns only
   the compact report. Heavy tokens burn on Copilot, not Claude.

Route by context ceiling (slice working set must fit the worker):
- claude-opus-4.8   200K — deepest reasoning; only slices ≤~150K.
- gpt-5.6-sol       400K — default flat-rate worker, breadth, second opinion.
- claude-sonnet-4.6   1M — huge-context scouting/reads.
- gpt-5.4-mini / gpt-5-mini — cheap mechanical fan-out.
- gpt-5.3-codex — code-only slices with no cross-contract risk.
Size slices to fit ≤200K so any worker can take them. Split before exceeding.

Delegate when a unit is independent AND token-heavy or numerous. Keep inline:
dependency graph, merge/integration judgment, final verification, the
user-facing answer. Verify a delegate's load-bearing claims before reporting
them as fact. For full multi-slice PRDs, hand the run to the orchestrate skill.

If `pi` or Copilot auth is unavailable, run natively. Launch flags, headers,
handoff template, and report schema: read `~/.claude/DELEGATION.md` when
delegating (not auto-loaded — keeps this file thin).

Every detached subagent — Agent-tool background launch, Workflow `agent()`
call, or Pi shell-out — states the model and thinking/effort mode it was
launched at in its run header and UI label. Default is to inherit the parent
thread's own model/effort; say so explicitly rather than leaving it implicit.
FleetView rows must be self-identifying, not generic. Format: `~/.claude/DELEGATION.md`.
