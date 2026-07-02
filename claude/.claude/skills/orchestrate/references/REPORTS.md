# Orchestrate Report Formats

## Final report

```text
Status
- COMPLETE | PARTIAL | BLOCKED

Slices
- <slice-id>: CLEAN | BLOCKED | SKIPPED — note

Files changed
- path
- path

Contracts
- Tool inputs:
  - change
- Persisted schema:
  - change
- API/payloads:
  - change
- Storage:
  - change

Behavior
- Area:
  - change
- Area:
  - change

Parallelism
- Scouts: parallel | serialized — reason
- Implementations:
  - wave 1: slice ids
  - wave 2: slice ids
- Worktrees:
  - slice-id: path
- Merge:
  - direct | merge-agent | serialized — reason

Subagent runs
- role=<role> slice=<id|none> subagent_type=<type> model=<value|default> status=<clean|fixed|blocked>

Verification
- command — result
- command — result

Warnings
- existing warning or skipped test, if relevant

Open risks
- unresolved only

Manual verification
- checklist item
- checklist item
```

## Scout report

```text
Surface map
- file:line refs only

Single-slice assumptions
- bullets

Cross-slice risks
- bullets

Suggested ownership
- slice-id -> files/areas

Tests to run
- exact commands
```

## Claim verifier report

```text
FINDING C1 | Verified | justification with file:line evidence
FINDING C2 | Weakened | justification with file:line evidence
FINDING C3 | Falsified | justification with file:line evidence
```

## Implementation report

```text
Implemented
- file/path — one-line reason

Verification
- command — result

Contracts
- payload/schema/tool/storage behavior changed

Blockers
- unresolved only
```

## Verifier report

```text
blocker|concern|suggestion | file:line | requirement violated | required fix
```

If clean:

```text
CLEAN
```

## Merge report

```text
Merged
- slice-id: branch/commit

Conflicts resolved
- file/path — resolution

Semantic checks
- contract/fixture/logging assumptions reconciled

Verification
- command — result

Risks
- unresolved only
```
