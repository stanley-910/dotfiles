---
name: remember-context
description: Distills a user-provided note, file reference, or chat decision into terse durable project memory. Use when user asks to remember context, add to AGENTS.md, save project memory, or invokes /skill:remember-context with a note string.
---

# Remember Context

Goal: add only durable, high-signal memory to project `AGENTS.md`.

## Workflow

1. Treat text after invocation as memory candidate. It may reference files with `@path`.
2. Read root `AGENTS.md`. If missing, create it.
3. Add/update the smallest useful note. Prefer existing section; else add `## Project memory`.
4. Deduplicate. Update stale bullets instead of appending near-duplicates.
5. Keep edit tiny. No summaries of whole chat unless user asks.

## Keep

- Durable rules future agents should obey.
- Gotchas that caused bugs.
- File-specific invariants.
- Verified decisions with reason/effect.
- Commands/tests required for a known area.

## Drop

- Temporary progress.
- Speculation.
- Obvious repo facts.
- Long prose.
- Raw logs/output.
- Secrets/tokens/user data.
- Anything useful only for current turn.

## Style

Use bare cause -> effect.

Format examples:

```md
- `src/http.py`: never log bodies/full URLs -> token/session leak risk. Use `redact_url(...)`.
- Streaming errors happen inside generator -> catch there; outer `StreamingResponse` try/except misses them.
- Azure OpenAI: use `AsyncOpenAI` + `/openai/v1/` base_url, not `AzureOpenAI`/`api-version`.
```

Limits:

- 1-5 bullets per invocation.
- Each bullet <= 160 chars unless impossible.
- Prefer one bullet.
- Preserve existing wording when adequate.

## Output

After edit, reply only:

```text
Added to AGENTS.md:
- <bullet>
```

Or:

```text
No durable memory added: <short reason>
```
