# Global preferences

## Commits

- Never add `Co-Authored-By: Claude ...` trailers to commit messages. No Claude attribution in git history, in any project. The commit message should end with the body — no attribution footer.

@RTK.md

## Fable-5-first delegation

Driver is Fable 5. It orchestrates — plans, decomposes, dispatches, verifies,
integrates, synthesizes. It does not run token-heavy or parallel work itself.

Native Claude workflows stay available — use the Agent tool with Claude models
whenever the work genuinely needs Claude. Separately, offload token-heavy or
parallelizable work to the flat-rate enterprise Copilot fleet via the Pi
harness. Two ways to reach it:

1. Direct — driver shells out (its context absorbs the transcript):
   `pi -p --provider github-copilot --model <id>:<thinking> "<handoff>"`
2. Token-saving via a Claude workflow — when you want the Agent tool's
   parallel/background orchestration but the reasoning cost to land on the
   flat-rate fleet, launch a cheap `sonnet` (low) wrapper subagent that does no
   reasoning itself: it `exec`s the `pi` command above, waits, and returns only
   the compact report. Heavy tokens burn on Copilot, not Claude.

Route by context ceiling (slice working set must fit the worker):
- claude-opus-4.8   200K — deepest reasoning; only slices ≤~150K.
- gpt-5.5           400K — larger token loads, breadth, second opinion.
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
