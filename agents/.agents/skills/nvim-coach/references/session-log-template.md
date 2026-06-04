# Session Log Template

Use when creating a session log programmatically. Replace all `<placeholder>` values. Filename: `YYYY-MM-DD-<kebab-topic>.md` in `<vault>/04-code/training-arc/neovim/`.

---

```markdown
---
tags:
  - practice
  - neovim/coaching
date: <YYYY-MM-DD>
phase: <0-7>
topic: "<one-line topic, e.g. 'autocommands: cleared augroups'>"
help-tags-read:
  - "<:help tag 1>"
  - "<:help tag 2>"
duration-min: <integer, ask or estimate>
nvim-version: "<output of nvim --version line 1>"
silly-mistakes-count: <integer>
score:
  correctness: <1-5>
  idiomatic-api: <1-5>
  structure: <1-5>
  docs-grounding: <1-5>
  robustness: <1-5>
  readability: <1-5>
focus-areas:
  - <recurring weakness 1>
  - <recurring weakness 2>
up: "[[04-code/training-arc/neovim/neovim|neovim]]"
related:
  - "[[04-code/neovim/neovim|neovim]]"
---

## Task

<Restate the exact task, including the file it went in and constraints.>

## My Attempt

```lua
<paste the learner's config verbatim>
```

## Loads & Lint

```
<verbatim output of nvim --headless load check + any luacheck/stylua>
```

## Evaluation

| Dimension              | Score | Notes |
|------------------------|-------|-------|
| Correctness            |       |       |
| Idiomatic API (0.11+)  |       |       |
| Structure & load order |       |       |
| Docs grounding         |       |       |
| Robustness             |       |       |
| Readability            |       |       |

**Pattern to watch:** <1-2 sentence summary of the most important recurring theme.>

## Reference Solution

```lua
<annotated ideal implementation, each non-obvious choice tied to its :help tag>
```

## Silly Mistakes

Known mistakes hit this session (cross-reference silly-mistakes.md). "none" if clean.

- <id> — <what they did and why it's a repeat>

## :help References

Tags read/looked up this session. Reproduce a section with:
`nvim --headless -c "help <tag>" -c "%print" -c "qa!" 2>/dev/null`

| `:help` tag | What it covers | Key line |
|---|---|---|
| `<tag>` | <topic> | <one excerpt line> |

## Key Takeaways

- <actionable lesson 1>
- <actionable lesson 2>
- <actionable lesson 3>
```
