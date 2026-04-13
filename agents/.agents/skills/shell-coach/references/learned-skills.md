# Learned Skills Catalog

Running list of concepts, tools, and patterns Stanley has demonstrated understanding of.
Use this in future sessions to prompt recall instead of giving direct answers.

---

## Shell Concepts

- **Scalar vs array variables** — knows the difference; knows scalars don't word-split in zsh for loops
- **`${(f)var}` parameter expansion** — splits scalar on newlines into array elements
- **`set -euo pipefail`** — knows what each flag does; uses it by default
- **`set -x` tracing** — knows to use it to see expanded commands rather than guessing
- **`continue` in loops** — knows it skips to next iteration
- **`[[ ]]` conditionals** — knows to use over `[ ]`; knows glob matching with `==`
- **`$()` command substitution** — knows the pattern; knows it strips trailing newlines
- **`IFS= read -r`** — knows the pattern for safe line-by-line reading, and why each part is needed
- **`dirname` / `basename`** — knows these as simpler alternatives to path splitting
- **`:l` modifier** — lowercase a string with `${var:l}`
- **Double-mv rename trick** — rename via temp name to work around case-insensitive filesystems

## Tools

- **`fd`** — knows `-t d` for directory filter, `"^name$"` for exact match, regex is default
- **`rg`** — knows `-l` for files-with-matches only
- **`perl -i -pe`** — knows the flags; knows to drop `-i` for dry run
- **`sed`** vs **`perl`** — knows when each is appropriate; prefers perl for context-aware regex
- **`MANPAGER=cat man <tool> | col -b | grep`** — knows this pattern for navigating man pages
- **`<tool> --help | grep`** — knows this as a faster alternative for simple flag lookups

## Debugging Patterns

- **Drop `-i` from perl for dry run** — test substitutions before applying in-place
- **`set -x` to trace expansions** — empirically verify what a command receives as arguments
- **`print -r --`** — print expanded command without executing
