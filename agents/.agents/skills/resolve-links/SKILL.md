---
name: resolve-links
description: Find unresolved or miscategorized wikilinks in an Obsidian note, place them in the correct frontmatter field (utils, concepts, related, etc.), and create minimal hub notes in the correct vault location with proper frontmatter. Invoke when the user asks to "resolve links", "create hub notes", "clean up references", or "fix unresolved backlinks" in a note.
argument-hint: [note path or note name]
---

# Resolve Links

Given a note (or set of notes), find all wikilinks — in frontmatter and body — that either:
- point to a non-existent file (unresolved), or
- exist but are placed in the wrong frontmatter field

Then: create missing hub notes in the correct location, and update the source note's frontmatter to properly categorize every reference.

---

## Step 0 — Load Vault Context

Before doing anything, read:
1. `99-toolbox/vault-style-guide.md` — for tag taxonomy, folder placement rules, and concept note format
2. The folder structure of `04-code/` — to understand where new notes should live

---

## Step 1 — Read the Target Note

Read the note specified by the user. Extract every wikilink from:
- Frontmatter fields (`utils`, `concepts`, `related`, `up`, `log`, etc.)
- Body text (inline `[[...]]` links)

List them all. Mark each as:
- **resolved** — a file with that name exists somewhere in the vault
- **unresolved** — no file found

Use `find` or `Glob` to check for existence. Wikilinks resolve by filename, not path, so search vault-wide.

---

## Step 2 — Categorize Each Link

For each unresolved link, determine which category it belongs to. Use the following rules:

| Category | Frontmatter field | Tag pattern | When to use |
|---|---|---|---|
| CLI tool / utility | `utils` | `shell/tool` | fd, ripgrep, jq, fzf, etc. |
| Shell concept | `concepts` | `shell/concept` | word splitting, parameter expansion, etc. |
| CS/theory concept | `concepts` | `cs/concept` | cross-domain theory |
| Language | `concepts` | `lang/<name>` | Perl, Python, Go, etc. |
| System/OS concept | `concepts` | `sys/concept` | APFS, filesystems, etc. |
| Lateral peer note | `related` | (none required) | similar scripts, related how-tos |

If the category is ambiguous, ask the user before proceeding.

---

## Step 3 — Determine Correct Location

Use the vault structure to place each new hub note. Key rules from the style guide:

- CLI tools → `04-code/command-line/tools/<Tool Name>.md`
- Shell concepts → `04-code/command-line/<Concept Name>.md`
- CS theory concepts → `04-code/concepts/<Concept Name>.md`
- Languages → `04-code/languages/<Language>/<Language>.md`
- macOS-specific → `04-code/macos/<Note Name>.md`
- Linux/distro-specific → `04-code/distros/<distro>/<Note Name>.md`
- System concepts → `04-code/distros/` or `04-code/macos/` depending on OS

Concept note filenames use **Title Case** (FILE-01).
If a parent folder doesn't exist yet, create a folder note alongside the new note.

---

## Step 4 — Create Hub Notes

For each unresolved link, create a minimal hub note:

```markdown
---
tags:
  - <tag from category table>
up: "[[path/to/parent-folder-note|display name]]"
---

![[Concept Link.base]]
```

Do not add body content — hub notes aggregate via backlinks. Keep them minimal.

If the parent folder note doesn't exist, create it too:

```markdown
---
tags:
  - overview
up: "[[path/to/grandparent|display]]"
---

![[folder-note.base]]
```

---

## Step 5 — Update Source Note Frontmatter

Move or add each wikilink to the correct frontmatter field in the source note:

- `utils` — CLI tools
- `concepts` — concept hub links (shell, CS, language, system)
- `related` — lateral peer notes, related how-tos, reference notes

Do not duplicate a link across fields. Remove it from `body` references only if the user explicitly asks — inline wikilinks in the body serve a different purpose (contextual) and should generally be left alone.

---

## Step 6 — Report

List:
- Links that were already resolved (no action taken)
- Hub notes created (path + tag used)
- Frontmatter fields updated
- Any ambiguous links skipped (with reason)
