# Session Log Template

Use this template when creating a session log programmatically. Replace all `<placeholder>` values. The filename should follow: `YYYY-MM-DD-<kebab-task-name>.md`

---

```markdown
---
tags:
  - practice
  - shell/coaching
date: <YYYY-MM-DD>
task: "<one-line task description>"
duration-min: <integer, ask user or estimate>
shellcheck-issues: <count of SC#### warnings, or "skipped" if shellcheck unavailable>
silly-mistakes-count: <integer — number of times the user hit a known silly mistake during the session>
score:
  correctness: <1-5>
  error-handling: <1-5>
  quoting: <1-5>
  readability: <1-5>
  efficiency: <1-5>
  portability: <1-5>
focus-areas:
  - <recurring weakness 1>
  - <recurring weakness 2>
up: "[[scripting]]"
related:
  - "[[<peer notes, similar scripts, relevant concepts>]]"
utils:
  - "[[<tools used in the script>]]"
log: "[[<path to freeform notes taken during this session, if any>]]"
---

## Task

<Restate the exact challenge that was presented, including constraints.>

## My Attempt

```bash
<paste user's script verbatim>
```

## Shellcheck Output

```
<paste shellcheck output verbatim, or "shellcheck not available — install with brew install shellcheck">
```

## Evaluation

| Dimension        | Score | Notes |
|------------------|-------|-------|
| Correctness      |       |       |
| Error handling   |       |       |
| Quoting & safety |       |       |
| Readability      |       |       |
| Efficiency       |       |       |
| Portability      |       |       |

**Pattern to watch:** <1-2 sentence summary of the most important recurring theme from this session.>

## Reference Solution

```bash
<annotated ideal implementation>
```

## Silly Mistakes

List any known silly mistakes the user hit during this session (cross-reference silly-mistakes.md). If none, write "none".

- <mistake id> — <brief description of what they did and why it's a repeat>

## Man Page References

Flags and features looked up during this session. Use `MANPAGER=cat man <tool> | col -b | grep -A N '<flag>'` to reproduce.

| Tool / Man Page | Flag or Feature | Excerpt |
|---|---|---|
| `man <tool>` | `--flag` | _paste relevant line(s) from man output_ |

## Key Takeaways

- <Specific, actionable lesson 1>
- <Specific, actionable lesson 2>
- <Specific, actionable lesson 3>
```
