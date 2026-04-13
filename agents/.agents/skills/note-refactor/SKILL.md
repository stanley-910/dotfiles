---
name: note-refactor
description: Refactor Obsidian notes to follow vault conventions — concept hubs in domain folders, correct frontmatter (tags, up, related, domains, aliases), `nascent`/`_drafts/` workflow for unfinished work, and the `00-inbox/` triage dashboard. Use when reorganising concepts, promoting drafts, fixing broken wikilinks, or extracting concepts from old context notes.
argument-hint: [note path or topic area]
---

# Note Refactor

Refactor Obsidian notes in this vault to follow established conventions. The vault style guide at `99-toolbox/vault-style-guide.md` is the source of truth — this skill encodes how to apply it during refactoring tasks. When in doubt, read the style guide and prefer its rules over anything restated here.

## Vault Path

```
/Users/stanley/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes-v1/
```

---

## Where Concept Notes Live

**Per NOTE-01:** concept notes live in their **domain folder**, not in a centralized `concepts/` directory.

- `04-code/git/Git Worktrees.md` ✓ — git concept lives in the git domain folder
- `04-code/concepts/Typecasting.md` ✓ — *cross-domain* CS theory concepts live in `04-code/concepts/`
- `04-code/concepts/Git Worktrees.md` ✗ — wrong folder; this is a git-specific concept

`04-code/concepts/` is reserved for **cross-domain CS theory** (Typecasting, Big O, Theory of Computation, complexity theory subconcepts, automata theory subconcepts, etc.). Anything tied to a specific tool, language, or framework lives in that tool's domain folder.

**There is no `04-code/fields/` folder. Domain folders ARE the fields.** A domain folder note (e.g., `04-code/git/git.md`) plays the role of a field hub via its `index` tag and `Concept Link.base` aggregation.

---

## Concept Note Frontmatter

```yaml
---
tags:
  - cs/concept           # or git/concept, ml/concept, tool/concept, etc. — domain-prefixed
up: "[[Parent Hub]]"     # single parent in the idea hierarchy
domains:                 # OPTIONAL — only on cross-cutting concepts (NOTE-08)
  - "[[Other Field]]"
related:                 # OPTIONAL — peer concept references
  - "[[Peer Concept]]"
aliases:                 # OPTIONAL — short names for Cmd+O
  - Short Name
---

A concise one-sentence definition.

![[Concept Link.base]]
```

**Field semantics — keep them straight, do not duplicate signals (TAG-DEDUP):**

| Field | What it expresses | Single or list | Used on |
|---|---|---|---|
| `up` | The single primary parent in the idea hierarchy | single | every note (FM-02) |
| `domains` | Fields a concept *also* belongs to (cross-cutting) | list | concept notes only, when applicable (NOTE-08) |
| `related` | Peer concept references at roughly the same level | list | any note |
| `concepts` | Hubs that *this note applies or instantiates* | list | non-concept notes (lectures, projects) pointing AT hubs |
| `tags` | Note type and domain marker (`<domain>/concept`, `index`, `wip`, `nascent`) | list | every note |

**Critical:** `domains:` is **distinct** from `concepts:`.
- `concepts:` lives on a *non-concept* note (lecture, project) pointing UP at a concept hub it references
- `domains:` lives on a *concept* note expressing that the concept itself spans multiple fields

---

## Hub Notes

A **hub** is a concept note with `index` in its tags. It embeds `Concept Link.base` (already inherited by every concept note) and serves as the discoverable entry point for a sub-area.

**Per NOTE-09:** hubs are created **on demand**, not preemptively. Promote a topic to a hub when:
- 3+ concept notes are pointing `up` to the same parent, OR
- A project or working session needs to reference all of them collectively, OR
- You catch yourself wanting to "see all of them in one place"

Do **not** pre-scaffold hubs for topics that don't yet have child concepts. Empty stubs degrade signal.

### Domain folder notes ARE hubs

A domain folder note (e.g., `04-code/git/git.md`, `04-code/compilers/compilers.md`) is automatically a hub for that domain — it carries `index` and the domain tag, and `Concept Link.base` aggregates all backlinks. Don't create a parallel "hub" note alongside the folder note; the folder note IS the hub.

---

## Drafts, Nascent Topics, and Refactoring Old Notes

The vault has a structured workflow for unfinished work, governed by **NOTE-10a/b/c**.

### Two complementary mechanisms

| Mechanism | When to use | Where it lives |
|---|---|---|
| **`nascent` tag** | Content is already living inside another note (lecture, project) and you don't want to move the file | Tag the host note `nascent` in place |
| **`_drafts/` subfolder** | You're deliberately creating a stub note knowing it isn't ready | Place the file at `04-code/<domain>/_drafts/<name>.md` |

Both routes surface in `00-inbox.md` via Bases queries (`nascent.base`, `drafts.base`). Use whichever fits the situation.

### `nascent` vs `wip` — they are not the same

- **`wip`** — actively being edited *this week*. The author is on it now.
- **`nascent`** — dormant capture. "This exists, will mature later, no active work."

Tag accordingly. `00-inbox/00-inbox.md` shows them in separate Bases views so prioritization works.

### Extracting a concept from an old context note

When you find an old note (e.g., `02-university/comp-551/lecture-7.md`) that contains a hub-worthy definition of a concept that doesn't yet have its own note:

1. **Create the new concept note** in the correct domain folder per NOTE-01 (e.g., `04-code/concepts/Gradient Descent.md` for cross-domain CS theory, or `04-code/ml/Gradient Descent.md` if there's an ML domain folder)
2. **Apply the concept template** (`99-toolbox/templates/cs-concept-template.md`) — note that the templater regex `^04-code/concepts/[^/]+\.md$` only auto-applies it to top-level files in `04-code/concepts/`, not subfolders
3. **Link from the old note** by adding `[[Gradient Descent]]` inline AND adding `concepts: [[Gradient Descent]]` to the old note's frontmatter (per NOTE-02b)
4. **Leave the old note in place** — context-specific notes stay in their context folder (NOTE-02b)

The new concept note's `Concept Link.base` will surface the old note via backlinks automatically.

### Promoting a draft from `_drafts/`

When a stub in `04-code/concepts/_drafts/` (or another `_drafts/` folder) is ready:

1. Remove the `nascent` tag from frontmatter
2. Move the file out of `_drafts/` to its proper location (one folder up — into the parent domain folder)
3. Verify `up`, `tags`, `related`, `domains` (if applicable) are all set
4. Confirm the body has the `![[Concept Link.base]]` embed

---

## The `00-inbox/` Dashboard

`00-inbox/00-inbox.md` is the global triage entry point, mirroring the existing `00-tasks/` structure. It embeds four Bases views:

| View | Filter | Purpose |
|---|---|---|
| `views/nascent.base` | `file.hasTag("nascent")` | Topics gathering content, awaiting crystallization |
| `views/wip.base` | `file.hasTag("wip")` | Active drafts being edited |
| `views/orphans.base` | `!file.hasProperty("up")` | Notes missing the required `up:` field (unrefactored, per FM-02) |
| `views/drafts.base` | `file.path.contains("/_drafts/")` | Notes living in any `_drafts/` subfolder |

Open `00-inbox.md` to see all four queues in one place. Refactor work flows through these queues.

The `00-inbox/` folder is also a general-purpose triage zone — light reminders, half-thoughts, and "deal with this later" capture notes may live as ad-hoc files directly inside it.

---

## Workflow

### Refactoring a single note

1. **Read** the note and identify what's broken: missing/wrong `up`, broken wikilinks, missing `tags`, wrong folder per NOTE-01, missing `Concept Link.base` embed, missing `domains:` for cross-cutting concepts
2. **Read surrounding notes** to understand the existing hierarchy before changing `up:`
3. **Fix frontmatter** in this order: `tags` → `up` → `domains` (if needed) → `related` → `aliases`
4. **Create missing notes** for unresolved wikilinks using `cs-concept-template.md` (or the appropriate domain template)
5. **Move the file** if NOTE-01 says it belongs in a different domain folder
6. **Verify** all wikilinks resolve

### Working through the orphan queue

1. Open `00-inbox/00-inbox.md`, scroll to the orphans view
2. For each orphan: read it, decide if it's a concept (extract per NOTE-02b workflow) or just needs frontmatter added in place
3. After fixing, the orphan disappears from the view automatically (it now has `up:`)

### Working through the nascent queue

1. Open `00-inbox/00-inbox.md`, scroll to the nascent view
2. For each nascent note: decide whether it's ready to crystallize into a hub (NOTE-09) or still gathering
3. If ready: promote it (create hub if needed, ensure 3+ child concepts point at it, remove `nascent` tag)
4. If still gathering: leave it tagged

---

## Common Mistakes to Avoid

- **Creating a `04-code/fields/` folder** — this duplicates the existing domain folder system. Domain folders ARE fields.
- **Adding a `field` tag** — use `index` (already documented). No new top-level tag needed.
- **Multi-valued `up:`** — `up:` is single-valued. Use `domains:` for cross-cutting membership (NOTE-08).
- **Pre-scaffolding hubs** — create hubs only on demand (NOTE-09). Empty stubs degrade signal.
- **Putting `domains:` on a non-concept note** — `domains:` is for concept notes only. Non-concept notes use `concepts:` to point AT hubs (NOTE-08, FM-03).
- **Tagging a note both `wip` and `nascent`** — pick one. `wip` = actively editing now; `nascent` = dormant capture.
- **Moving context-specific notes into `concepts/`** — lecture/project notes stay in their context folder per NOTE-02b. Extract a concept *from* them; don't relocate them.

---

## Templater File Regex

The templater config in `.obsidian/plugins/templater-obsidian/data.json` includes:

```
^04-code/concepts/[^/]+\.md$  →  cs-concept-template.md
```

This auto-applies the concept template to **top-level** files in `04-code/concepts/`. Notes in subfolders (e.g., `04-code/concepts/Complexity Theory/`, `04-code/concepts/_drafts/`) **do not match** and need the template applied manually (or via QuickAdd).

---

## Reference: Style Guide Rules Used by This Skill

- **NOTE-01** — concept notes in domain folders; `04-code/concepts/` for cross-domain CS theory only
- **NOTE-02** — concept notes embed `![[Concept Link.base]]`
- **NOTE-02b** — context-specific notes stay in their context folder; link via `concepts:` or inline wikilink
- **NOTE-03** — keep body prose minimal
- **NOTE-08** — `domains:` list for cross-cutting concepts
- **NOTE-09** — hubs created on demand, not preemptively
- **NOTE-10a** — `nascent` tag for dormant capture (≠ `wip`)
- **NOTE-10b** — `_drafts/` subfolders for deliberate stubs
- **NOTE-10c** — `00-inbox/` as global triage dashboard
- **FM-01** — `tags` required on every note
- **FM-02** — `up` required (except top-level folder notes)
- **FM-03** — `domains:` only on concept notes
- **TAG-DEDUP** — never duplicate signals between tags and `concepts:`/`domains:`
