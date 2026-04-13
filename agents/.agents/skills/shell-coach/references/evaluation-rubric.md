# Shell Scripting Evaluation Rubric

For an intermediate bash/zsh learner. Score each dimension 1–5: 5 = solid, 3 = needs work, 1 = missing/broken. Use the descriptions below to calibrate.

---

## 1. Correctness

Does the script actually solve the stated task?

**5 — solid**
- Produces correct output for the happy path
- Handles all specified edge cases (empty input, missing args, no matches)
- Arguments and options behave as described

**3 — needs work**
- Core logic is right but edge cases are missed
- Output is correct but formatted wrong
- Works for the specific example but breaks on variations

**1 — missing**
- Logic error produces wrong output
- Script doesn't address the task

---

## 2. Error Handling

Does the script fail safely and loudly?

**5 — solid**
- `set -euo pipefail` (or equivalent guards) at top
- Error messages go to stderr: `echo "error: ..." >&2`
- Explicit exit codes for different failure modes
- `trap` used for cleanup (temp files, locks) if applicable
- Missing required args caught early with usage message

**3 — needs work**
- Has some error handling but missing one or two of the above
- Error messages go to stdout instead of stderr
- Script exits on error but without a clear message

**1 — missing**
- No `set -e` equivalent — silent failures possible
- No argument validation
- No cleanup on failure

**Key patterns to check:**
```bash
#!/usr/bin/env bash
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[[ $# -eq 0 ]] && die "usage: $0 <arg>"

trap 'rm -f "$tmpfile"' EXIT
```

---

## 3. Quoting & Safety

Are expansions safe from word splitting and glob expansion?

**5 — solid**
- All variable expansions quoted: `"$var"`, `"$@"`, `"${array[@]}"`
- Arrays used for commands with multiple arguments
- `[[ ]]` used for conditionals (not `[ ]`) in bash
- No unquoted expansions in paths, loops, or comparisons

**3 — needs work**
- Most variables quoted but a few stray unquoted expansions
- `[ ]` used where `[[ ]]` would be safer

**1 — missing**
- Widespread unquoted `$var` — word splitting bugs likely with filenames containing spaces
- Using `$*` instead of `"$@"` for argument passing

**Common pitfalls:**
```bash
# ❌ breaks on spaces in filenames
for f in $files; do ...

# ✅ safe
for f in "${files[@]}"; do ...

# ❌ glob expansion risk
ls $dir/*

# ✅
ls "$dir"/*
```

---

## 4. Readability

Is the script easy to understand and maintain?

**5 — solid**
- Descriptive variable and function names (`input_file`, not `f` or `x`)
- Functions used to break up multi-step logic (>30 lines of main logic is a signal)
- Script has a clear top-to-bottom flow: setup → validate → main logic → cleanup
- Brief comments on non-obvious logic (not line-by-line narration)
- Consistent style: indentation, brace placement

**3 — needs work**
- Logic is correct but hard to follow in one pass
- Magic values not explained
- Single-letter variables used beyond loop iterators

**1 — missing**
- Monolithic script with no structure
- Abbreviations and cryptic variable names throughout

---

## 5. Efficiency

Does the script avoid unnecessary work?

**5 — solid**
- Prefers shell builtins over spawning subprocesses for simple operations
- No useless use of `cat` (UUOC): `grep pattern file`, not `cat file | grep pattern`
- No unnecessary subshells: `var=$(< file)`, not `var=$(cat file)`
- Pipelines kept lean — no intermediate files when not needed
- Loops over files use globs or `find` properly, not `ls`

**3 — needs work**
- One or two unnecessary subshells or `cat` usages
- A loop that could be a single pipeline

**1 — missing**
- Multiple UUOC or needless `echo | ...` patterns
- Repeatedly calling external commands inside a tight loop

**Common antipatterns:**
```bash
# ❌ UUOC
cat file | grep pattern | wc -l

# ✅
grep -c pattern file

# ❌ unnecessary subshell
content=$(cat file)

# ✅
content=$(< file)

# ❌ parsing ls
for f in $(ls *.txt); do ...

# ✅
for f in *.txt; do ...
```

---

## 6. Portability

Is the shebang correct? Are bash/zsh distinctions handled?

**5 — solid**
- Shebang uses `#!/usr/bin/env bash` (or `zsh`) — not `/bin/bash` hardcoded
- If targeting bash: avoids zsh-only syntax (`=~` array handling, etc.)
- If targeting POSIX sh: avoids bashisms (`[[ ]]`, `local`, arrays, `$(())`)
- Script notes its requirements (bash 3.2+, bash 4+, etc.) if relevant

**3 — needs work**
- Shebang present but uses hardcoded path (`#!/bin/bash`)
- Uses a few bash 4+ features without noting the dependency
- Mixes bash and zsh idioms inconsistently

**1 — missing**
- No shebang — interpreter unknown
- Uses bash arrays in a `#!/bin/sh` script

**Note for this learner (bash/zsh focus):** Flag bash vs. zsh behavioral differences explicitly when they appear (e.g., `${array[@]}` quoting, `read` behavior, glob behavior with `setopt globdots`).
