# Git Deep-Dive (maintenance-gear supporting track)

Goal: become genuinely proficient at Git — understand it deeply, navigate it
confidently — not memorize incantations. This is a **career-strengthening** track,
not interview-critical. It earns its place because (a) the user wants it, and (b)
Git's internals reinforce the exact systems intuition that helps the Databricks
design round (see the Delta Lake bridge below).

## Gearing (important)
- **Maintenance gear only.** This is a leisure-paced, fried-weeknight activity: when
  the brain is too cooked for a hard DP problem, a Git internals lesson is a
  productive lower-intensity alternative that still keeps the streak alive.
- **Pause in sprint gear.** The moment an interview is scheduled and the user flips
  to sprint, Git pauses — sprint is interview-critical work only (mocks, gaps,
  design, behavioral). This preserves the original logic: at crunch time Git still
  loses to interview prep; it just gets to exist during the long no-deadline stretch.
- **Not scheduled.** No "Git in week N" slotting — pursue at leisure, not on a
  calendar.

## Scope & sequence (don't redo what's already known)
The user is past basic add/commit/branch/merge/rebase. Skip most of Git 1.

1. **Git 1 — Internals chapter (high value):** how `.git` stores data — blobs,
   trees, commits as content-addressed objects; plumbing commands `git cat-file`,
   `git hash-object`, refs. This is the part that bridges to Delta Lake.
2. **Git 2 (the real depth):** advanced workflows — reflog, bisect, and the other
   power-user material.
3. **Pro Git ch 7 & 10 (to go exceptional):** advanced internals and power workflows;
   free at git-scm.com.

## The Delta Lake / systems bridge (why this is on-theme)
Git's object store is an **append-only, content-addressed** store; Delta Lake's
transaction log (`_delta_log/`) is an append-only commit log; DDIA's log-structured
storage (LSM trees, WALs) is the same family of idea. When coaching Git internals,
explicitly draw these parallels — it turns a "career nice-to-have" into reinforcement
for the system-design round.

## lazygit workflow mapping (requested)
The user uses lazygit and wants to **see the workflow differences**. So:
- When the user learns or practices something in **plain CLI Git**, tell them how the
  **same operation is done in lazygit** — the keybinding/panel/flow — so they can map
  one onto the other. Seeing both side by side aids their understanding.
- Do this proactively for operations where the lazygit flow differs meaningfully
  (staging hunks, interactive rebase, cherry-pick, stashing, resolving conflicts,
  branch/commit navigation), not just trivial 1:1 commands.

## DeepWiki MCP (tool use)
When a question turns on **how lazygit actually implements** something — or to verify
a lazygit workflow/keybinding rather than guess — use the **DeepWiki MCP server** to
check the lazygit repository. Prefer looking it up over guessing when the user is
relying on the answer to build a correct mental model. (DeepWiki is already among the
user's connected MCP servers.)

## Coaching style here
Same as everywhere: Socratic, no competence priors, hints after real effort. Probe
whether the user actually understands *why* an object hash is what it is, *why*
rebase rewrites history, etc. — don't assume from their lazygit familiarity that the
internals are understood (or that they aren't).
