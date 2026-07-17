---
name: orchestrate
description: Orchestrates multi-slice implementation from a PRD and issue files using scouting, implementation, verification, isolated worktrees, merge integration, and normalized reporting. Use when the user asks to orchestrate a PRD, run issue slices, coordinate subagents, execute an implementation runbook, or invokes /orchestrate.
---

# Orchestrate

## Style

Be direct. No pretty language. No praise. No filler. Use terse bullets. Do not hide uncertainty.

Do not implement the PRD in orchestrator context. The orchestrator coordinates, verifies, integrates, and reports.

## Inputs

Expected input:

```text
PRD: <path>
Issues:
- <issue path>
- <issue path>
Repo: <path> optional
Base: <branch/commit> optional
Constraints: optional
```

If PRD or issue paths are missing, ask.

## Required setup

1. Read PRD, issue slices, `AGENTS.md`, `CONTEXT.md`, and relevant repo docs.
2. Extract slice IDs, dependencies, acceptance criteria, invariants, likely touched files, and required commands.
3. Check repo state:

```bash
git status --short --branch
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
```

If dirty: preserve unrelated changes. Do not stash, overwrite, or commit source repo changes without asking.

## Worktree convention

Use deterministic worktrees.

```text
~/worktrees/<project-name>/<run-slug>/integration
~/worktrees/<project-name>/<run-slug>/<slice-id>
```

Rules:

- `<project-name>` = basename of git root.
- `<run-slug>` = `YYYY-MM-DD_<short-prd-slug>`.
- Branches:
  - `orchestrate/<run-slug>/integration`
  - `orchestrate/<run-slug>/<slice-id>`
- Do not edit the source repo unless user explicitly asks.
- Do not delete worktrees at the end. Report paths. Ask before cleanup.

Example:

```text
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/integration
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/a1-canonical-plan-policy
```

## Task tracking

Use `todo`. Use the same task subjects for every orchestration run.

Create these tasks in order:

```text
1. Read artifacts
2. Check repo state
3. Scout surfaces
4. Verify claims
5. Plan waves
6. Prepare worktrees
7. Run wave 1
8. Integrate wave 1
9. Run final verification
10. Report outcome
```

For additional waves, create:

```text
Run wave N
Integrate wave N
```

For blockers, create:

```text
Fix <slice-id> blocker
Fix integration blocker
```

Todo metadata, when available:

```json
{
  "orch_run_slug": "YYYY-MM-DD_short-prd-slug",
  "project": "project-name",
  "phase": "read|repo|scout|claims|plan|worktree|wave|integrate|verify|report|fix",
  "wave": 1,
  "slice": "a1-canonical-plan-policy"
}
```

Rules:

- Exactly one orchestrator task is `in_progress` at a time.
- Mark tasks complete immediately when done.
- Do not mark a wave complete until every slice in that wave has verifier `CLEAN`.
- Do not mark integration complete until merge/integration tests pass.
- If `Verify claims` is not needed, mark it complete with reason in description.
- Use `blockedBy` for wave/integration dependencies.

## Model selection

Pass model IDs through the Agent tool `model` parameter, not only in prompt text.

Use exact IDs when audit matters:

```text
model="provider/model-id"
```

Examples:

```text
model="github-copilot/gpt-5.4-mini"
model="github-copilot/gpt-5.6-sol"
model="github-copilot/claude-sonnet-4.6"
model="github-copilot/claude-opus-4.8"
```

Default general worker: `github-copilot/gpt-5.6-sol` with thinking `high`.
Use a different model or thinking level only for an explicit role-specific reason.

If using a custom agent with frontmatter `model:`, either:

- omit `model` and record `resolved_model=<frontmatter model>` in ledger; or
- override with an explicit `model` parameter and record that.

Do not use fuzzy model names for audit-critical agents. If fuzzy/default is used, record it honestly in the ledger.

Route by context ceiling. A slice's working set (repo reads + prompt + output) must fit the worker:

- `github-copilot/claude-opus-4.8` — 200K ctx. Deepest reasoning. Only slices ≤~150K (leave headroom for 64K output).
- `github-copilot/gpt-5.6-sol` — 400K ctx. Default general worker, breadth, and second opinion.
- `github-copilot/claude-sonnet-4.6` — 1M ctx. Huge-context scouting/reads.
- `github-copilot/gpt-5.4-mini` / `github-copilot/gpt-5-mini` — cheap mechanical fan-out.
- `github-copilot/gpt-5.3-codex` — code-only implementation slices with no cross-contract risk.

## UI-visible agent labels

The active Agents view shows the Agent tool `description`. Put the model tag there.

Description format:

```text
<Role> <slice|wave> <model-tag>
```

Examples:

```text
Scout A1 gpt5.4m
Claim PRD opus4.8
Impl A2 gpt5.6s
Verify A2 opus4.8
Merge W2 sonnet4.6
```

Model tags:

```text
github-copilot/gpt-5.4-mini       -> gpt5.4m
github-copilot/gpt-5.6-sol        -> gpt5.6s
github-copilot/claude-sonnet-4.6  -> sonnet4.6
github-copilot/claude-opus-4.8    -> opus4.8
default or unknown                -> default
```

Also make the first line of every subagent prompt a full audit header:

```text
RUN_LEDGER role=<role> slice=<id|none> requested_model=<exact|default> thinking=<level> worktree=<path|none>
```

This makes model assignment visible in both the Agents list row and the opened agent detail view.

## Subagent run ledger

Maintain a terse run ledger in orchestrator notes and final report.

Before launching agents in a wave, state the launch plan:

```text
Launch plan
- id-temp: role=<scout|claim|implement|verify|merge> slice=<id|none> subagent_type=<type> model=<exact|default-from-agent|fuzzy> thinking=<level> worktree=<path|none>
```

Then call `Agent` with matching fields. Example:

```text
Agent(
  subagent_type="general-purpose",
  model="github-copilot/gpt-5.6-sol",
  thinking="high",
  run_in_background=true,
  prompt="..."
)
```

After agents complete, report:

```text
Subagent runs
- role=<role> slice=<id|none> subagent_type=<type> requested_model=<value|default> resolved_model=<known|unknown> thinking=<level> status=<clean|fixed|blocked>
```

Rules:

- Prefer exact model IDs when model choice matters.
- Avoid fuzzy model names for audit-critical agents.
- If using a custom agent with frontmatter `model:`, report that as `resolved_model` when known.
- If the Agent tool output does not expose the resolved model, report `resolved_model=unknown` and keep `requested_model` accurate.
- Do not claim a model was used unless it is visible from the launch args, custom-agent frontmatter, or returned run metadata.

## Scouting

Launch read-only scouts first, in parallel, in one tool message.

Agents:

- `codebase-locator`, thinking `minimal`: file/symbol map.
- `integration-scanner`, thinking `minimal`: inbound/outbound dependencies.
- `codebase-analyzer`, thinking `low` or `medium`: only for deeper behavior.
- `codebase-pattern-finder`, thinking `low`: only for precedent patterns.
- `claim-verifier`, thinking `medium`: verify only load-bearing PRD/issue current-state claims.

Scout prompt requirements:

- repo path
- PRD path
- issue path or slice scope
- `Do not edit files.`
- max 80-line report
- format from `references/REPORTS.md`

## Claim verification

Use targeted claim verification. Do not add a full serial claim-verifier stage by default.

Default:

- extract at most 10 load-bearing current-state claims;
- run one `claim-verifier` in parallel with scouts;
- thinking `medium`;
- timebox by prompt: max 80 lines;
- do not block implementation unless a `Falsified` or important `Weakened` claim changes slice scope or dependencies.

Use `high` thinking only when a false claim would affect money movement, auth, storage migration, checkout/idempotency, privacy/logging, or cross-slice contracts.

Verify claims about:

- existing behavior;
- file/function locations;
- current schema/storage;
- current tests/fixtures;
- prior implementation assumptions.

Do not verify future desired behavior as if it already exists.

Process:

1. Orchestrator extracts concrete load-bearing claims from PRD/issues.
2. Assign stable IDs:

```text
C1: <claim>
C2: <claim>
```

3. Launch `claim-verifier` read-only in parallel with scouts.
4. Treat `Falsified` and important `Weakened` claims as planning risks.
5. If a falsified claim changes slice scope, update implementation prompts before launching implementers.
6. If claim verification is still running but no high-risk slice depends on it, start independent implementation work.

Claim verifier prompt must include:

- repo path
- PRD/issue paths
- numbered claims
- instruction to verify against actual repo state only
- max 80-line report
- report format from `references/REPORTS.md`

## Dependency waves

Build a dependency graph from PRD and issue files.

Rules:

- Run dependency-free slices first.
- Blocked slices wait.
- Same-wave slices should run in parallel.
- If same-wave slices may conflict, use separate worktrees. Do not serialize only because conflicts are possible.
- Serialize only when a slice needs another slice's actual code output, not just its contract.

Slice sizing:

- Target every slice so its working set fits ≤200K tokens, so any worker (including `opus-4.8`) can take it.
- Split before exceeding 200K. Only route an unsplittable >200K slice to a larger-context worker (`gpt-5.6-sol` ≤400K, `claude-sonnet-4.6` ≤1M).

## Implementation agents

One implementation agent per slice.

Agent:

- `general-purpose`
- thinking `low` for mechanical/docs/tests/prompts slices
- model `github-copilot/gpt-5.6-sol` with thinking `high` by default for well-scoped implementation
- thinking `high` only for schema/storage, auth, money/checkout, concurrency/idempotency, privacy/logging, or broad cross-layer slices
- for code-only slices with no cross-contract risk, prefer `model="github-copilot/gpt-5.3-codex"`
- use `run_in_background: true`
- run parallel wave agents in one tool message

Each implementation agent works in its own slice worktree.

Prompt includes only:

- slice worktree path
- PRD path
- one issue path
- relevant scout summary
- dependency contracts from already-clean slices
- acceptance criteria
- invariants
- exact tests
- report format from `references/REPORTS.md`

Do not assign multiple slices to one implementation agent unless user explicitly asks.

## Slice verification

After each implementation report, immediately launch a separate verifier.

Agent:

- `general-purpose`
- thinking `high` or `xhigh`
- read-only

Verifier prompt includes PRD path, issue path, changed files, implementation report, acceptance criteria, and `Do not edit files.`

Loop until clean:

```text
implement -> verify -> fix -> verify
```

A slice is not clean until verifier returns exactly `CLEAN`.

## Slice commits

After verifier returns `CLEAN`, create a local slice commit in that slice worktree for integration unless user forbids commits.

Commit style:

```text
orchestrate(<slice-id>): <short slice title>
```

Do not push.

## Merge integration

Clean parallel slices are not complete until integrated.

Direct merge is allowed only if:

- touched file sets are disjoint; and
- no shared schema, tool contract, payload, storage, logging, fixture, or eval harness changed.

Otherwise launch a merge/integration agent.

Merge agent:

- `general-purpose`
- thinking `medium` only for direct-ish/disjoint merges with no shared contract changes
- thinking `high` default for parallel slice integration
- thinking `xhigh` for overlapping files or shared contracts involving schema/storage, auth, money/checkout, concurrency/idempotency, privacy/logging, tool/API payloads, fixtures, or eval harnesses
- works in integration worktree
- merges/cherry-picks clean slice commits
- resolves textual conflicts
- detects semantic conflicts
- preserves each slice contract
- runs targeted cross-slice tests
- reports using `references/REPORTS.md`

The merge agent is not a blind conflict resolver. Give it an integration brief.

Merge-agent prompt must include:

- integration worktree path
- PRD path and relevant issue paths
- one-paragraph problem statement synthesized by orchestrator
- final target contracts/invariants that must survive the merge
- slice branches/commits to merge
- implementation reports for each slice
- verifier `CLEAN` reports for each slice
- touched-file lists for each slice
- scout summaries for overlapping/shared areas
- known semantic-risk areas
- exact tests to run
- instruction: if preserving both slice contracts is unclear, stop and report risk; do not guess

Do not dump the whole conversation. Provide enough context for semantic merge decisions.

The orchestrator reviews the merge report and final integrated diff. The merge agent is not final authority.

## Final verification

Run PRD-required commands. Minimum default:

```bash
uv run ruff check .
uv run pytest -q
```

If tooling differs, follow repo docs.

If tests fail: create blocker task, delegate fix, verify again. Do not report complete.

## Final report

Use `references/REPORTS.md`.

Must include:

- status
- slices completed
- files changed
- contract changes
- behavior changes
- parallelism/worktrees/merge method
- commands run and results
- warnings/skips
- open risks
- manual verification checklist
