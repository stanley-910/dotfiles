---
name: orchestrate
description: Orchestrates multi-slice implementation from a PRD and issue files using scouting, implementation, verification, isolated worktrees, merge integration, and normalized reporting. Use when the user asks to orchestrate a PRD, run issue slices, coordinate subagents, execute an implementation runbook, or invokes /orchestrate.
---

# Orchestrate

Claude Code variant. Adapted for the Claude Code Agent tool (`subagent_type`, `model`, `description`, no `thinking` param), TodoWrite, and explicit git worktrees.

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

1. Read PRD, issue slices, `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`, and relevant repo docs.
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

Create worktrees explicitly with git, then pass the absolute path into each agent prompt:

```bash
git worktree add -b orchestrate/<run-slug>/<slice-id> ~/worktrees/<project>/<run-slug>/<slice-id> <base>
```

Note: do NOT use the Agent tool's `isolation: "worktree"` option here. That worktree is ephemeral and auto-removed when unchanged — slice worktrees must persist for merge integration and post-run inspection. Own the worktree lifecycle yourself.

Example:

```text
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/integration
~/worktrees/madden-agent/2026-06-29_uc3-multi-item/a1-canonical-plan-policy
```

## Task tracking

Use `TodoWrite`. Use the same task subjects for every orchestration run.

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

TodoWrite items are plain text (`content` + `status`), with no metadata field. Encode phase/wave/slice in the subject when useful:

```text
Run wave 1 [a1, a2]
Integrate wave 1
Fix a1-canonical-plan-policy blocker
```

Rules:

- Exactly one orchestrator task is `in_progress` at a time.
- Mark tasks complete immediately when done.
- Do not mark a wave complete until every slice in that wave has verifier `CLEAN`.
- Do not mark integration complete until merge/integration tests pass.
- If `Verify claims` is not needed, mark it complete and note the reason.
- Track wave/integration dependencies in the subject; do not start a blocked task early.

## Model selection

Pass the model through the Agent tool `model` parameter, not only in prompt text. Claude Code accepts short names:

```text
model="opus"
model="sonnet"
model="haiku"
model="fable"
```

Exact IDs (record in ledger when audit matters):

```text
opus   -> claude-opus-4-8
sonnet -> claude-sonnet-4-6
haiku  -> claude-haiku-4-5-20251001
fable  -> claude-fable-5
```

Claude Code's Agent tool has no `thinking`/`effort` parameter. Express reasoning intensity through model tier:

```text
mechanical / docs / tests / prompts            -> haiku
standard well-scoped implementation            -> sonnet
high-stakes (schema/storage, auth, money/       -> opus
  checkout, concurrency/idempotency, privacy/
  logging, cross-slice merge, verification)
```

If a custom agent type carries its own default model, either omit `model` and record `resolved_model=<agent default>` in the ledger, or override with an explicit `model` and record that. Do not claim a model was used unless it is visible from the launch args or the agent's frontmatter.

## UI-visible agent labels

The active Agents view shows the Agent tool `description`. Put the model tag there.

Description format:

```text
<Role> <slice|wave> <model-tag>
```

Examples:

```text
Scout A1 haiku4.5
Claim PRD opus4.8
Impl A2 sonnet4.6
Verify A2 opus4.8
Merge W2 opus4.8
```

Model tags:

```text
opus    -> opus4.8
sonnet  -> sonnet4.6
haiku   -> haiku4.5
fable   -> fable5
default or unknown -> default
```

Also make the first line of every subagent prompt a full audit header:

```text
RUN_LEDGER role=<role> slice=<id|none> model=<opus|sonnet|haiku|fable|default> worktree=<path|none>
```

This makes model assignment visible in both the Agents list row and the opened agent detail view.

## Subagent run ledger

Maintain a terse run ledger in orchestrator notes and final report.

Before launching agents in a wave, state the launch plan:

```text
Launch plan
- id-temp: role=<scout|claim|implement|verify|merge> slice=<id|none> subagent_type=<type> model=<opus|sonnet|haiku|fable|default> worktree=<path|none>
```

Then call `Agent` with matching fields. Example:

```text
Agent(
  subagent_type="general-purpose",
  model="sonnet",
  description="Impl A2 sonnet4.6",
  run_in_background=true,
  prompt="RUN_LEDGER role=implement slice=a2 model=sonnet worktree=~/worktrees/... \n..."
)
```

After agents complete, report:

```text
Subagent runs
- role=<role> slice=<id|none> subagent_type=<type> model=<value|default> status=<clean|fixed|blocked>
```

Rules:

- Prefer explicit `model` when model choice matters.
- If using a custom agent type with its own default model, report that as the model when known.
- If the resolved model is not visible from the launch args or agent frontmatter, report `model=unknown` and keep the requested value accurate.
- Do not claim a model was used unless it is visible from the launch args, custom-agent frontmatter, or returned run metadata.

## Scouting

Launch read-only scouts first, in parallel, in one message.

Use `Explore` (read-only search agent) for surface mapping. Give each scout a distinct focus so they do not overlap:

- Surface map: files/symbols the slices touch. model `haiku` or `sonnet`.
- Integration scan: inbound/outbound dependencies of the touched areas. model `sonnet`.
- Precedent patterns: only when a slice should mirror existing code. model `haiku`.

Use `general-purpose` (read-only) for deeper behavior analysis, and only when a surface map is not enough. model `sonnet`.

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
- run one claim-verifier (`general-purpose`, read-only) in parallel with scouts;
- model `sonnet`;
- timebox by prompt: max 80 lines;
- do not block implementation unless a `Falsified` or important `Weakened` claim changes slice scope or dependencies.

Use model `opus` only when a false claim would affect money movement, auth, storage migration, checkout/idempotency, privacy/logging, or cross-slice contracts.

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

3. Launch the claim-verifier (`general-purpose`, read-only) in parallel with scouts.
4. Treat `Falsified` and important `Weakened` claims as planning risks.
5. If a falsified claim changes slice scope, update implementation prompts before launching implementers.
6. If claim verification is still running but no high-risk slice depends on it, start independent implementation work.

Claim verifier prompt must include:

- repo path
- PRD/issue paths
- numbered claims
- instruction to verify against actual repo state only
- `Do not edit files.`
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

## Implementation agents

One implementation agent per slice.

Agent:

- `general-purpose`
- model `haiku` for mechanical/docs/tests/prompts slices
- model `sonnet` default for well-scoped implementation when orchestrator provides exact files/contracts/tests
- model `opus` only for schema/storage, auth, money/checkout, concurrency/idempotency, privacy/logging, or broad cross-layer slices
- use `run_in_background: true`
- run parallel wave agents in one message (multiple Agent tool calls in a single assistant turn)

Each implementation agent works in its own slice worktree. The prompt must instruct it to operate only within the absolute worktree path.

Prompt includes only:

- slice worktree path (absolute)
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
- model `opus`
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
- model `sonnet` only for direct-ish/disjoint merges with no shared contract changes
- model `opus` default for parallel slice integration, and required for overlapping files or shared contracts involving schema/storage, auth, money/checkout, concurrency/idempotency, privacy/logging, tool/API payloads, fixtures, or eval harnesses
- works in integration worktree
- merges/cherry-picks clean slice commits
- resolves textual conflicts
- detects semantic conflicts
- preserves each slice contract
- runs targeted cross-slice tests
- reports using `references/REPORTS.md`

The merge agent is not a blind conflict resolver. Give it an integration brief.

Merge-agent prompt must include:

- integration worktree path (absolute)
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

Run PRD-required commands. Follow repo docs for the exact toolchain. If the repo is Python with uv, the minimum default is:

```bash
uv run ruff check .
uv run pytest -q
```

If tooling differs (npm/pnpm scripts, make targets, go test, cargo, etc.), use what the repo docs specify.

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
