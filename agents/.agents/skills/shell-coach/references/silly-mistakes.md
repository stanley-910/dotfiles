# Silly Mistakes Working Memory

Running list of mistakes Stanley has already made and should know to avoid.
Updated at the end of each session. Referenced at the start of each session.

---

## SM-1 — Confusing `fd` flags: `-d` is max-depth, not directory filter

**What happened:** Used `fd -d 100 "Attachments"` expecting `-d` to filter for directories only. It is `--max-depth`. Directory filtering requires `-t d`.

**Correct usage:**
```zsh
fd -t d "^Attachments$"
```

**First seen:** 2026-04-08, rename-attachment-folders session.

---

## SM-2 — Assuming `for f in $scalar` splits correctly in zsh

**What happened:** Stored `fd` output in a scalar variable and iterated with `for f in $results`, assuming zsh would split on newlines per line. Zsh does NOT word-split unquoted scalar variables by default — the loop ran once with the entire string as `$f`.

**Correct approach:** Use `${(f)results}` to explicitly split on newlines in zsh, or use `while IFS= read -r` for cross-shell safety.

```zsh
for f in ${(f)results}; do   # zsh: split scalar on newlines
```

**First seen:** 2026-04-08, rename-attachment-folders session.
