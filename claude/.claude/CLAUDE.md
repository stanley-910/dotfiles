# Global preferences

## Working with Stanley

- **Teaching/grilling style**: one question per turn, always with a recommendation.
  Feynman-simple — concrete mini-examples and short transcripts over abstraction.
  No filler, no fancy prose. Caveman mode only when explicitly invoked. Stanley's
  side-questions ("is dismiss a tool or a callback?") are evidence requests, not
  rhetorical — grep/verify before answering, and reverse your recommendation when
  the evidence says so.
- **Diagrams as we design**: maintain one growing mermaid class diagram per design
  effort (extend it each resolved decision) plus a sequence diagram for each
  behavioral flow. Code block in chat is enough. Never use `<br/>` in mermaid —
  Stanley pastes into Excalidraw, which doesn't render HTML breaks.
- **Ops hygiene**: verify VPN/connectivity before detaching subagents that need
  internal hosts (gitlab.ea.com). Resume a stalled subagent via SendMessage —
  don't relaunch and lose its context.
- **RTK is a compactor, not a corruptor**: rtk (@RTK.md) deliberately summarizes
  tool output to save tokens — dropped words and `N matches` rollups are the
  feature. Its summaries are for *reading*; never *parse* them. When you need
  exact/lossless bytes (JSON to `json.loads`, precise pass/fail counts,
  transcript-JSONL fidelity), bypass compaction: `rtk proxy <cmd>`, or redirect
  to a file and Read it.
- **Generated artifacts** (reports, briefs): write to durable paths (repo docs/,
  ~/.claude, or an agreed workspace) — never macOS `/var/folders` temp dirs;
  they purge within a day.
- **Citing past decisions**: state the rule in words; the record number is only a
  trailing breadcrumb — "checkout codes are never re-minted (ADR-0021)". The
  sentence must stand alone if the number is deleted. Never a bare "per ADR-0021"
  in chat, comments, or code.
- **Issue/comment skeleton** (issues, resolution comments, MR descriptions), in
  strict order: (1) **Story** — 3–6 line mini-transcript showing the problem as
  lived experience (can't write it → don't understand the problem yet);
  (2) **Why** — ≤5 plain-English sentences; (3) **Decision/fix** — ≤7 bullets;
  (4) **Agent detail** — file:line refs, payload shapes, edge cases — folded in a
  `<details>` block at the bottom.
- **Prose budget**: the human layer (1–3) must fit one screen unscrolled. At most
  one code snippet above the fold, ≤5 lines, illustrative only. One diagram
  allowed and encouraged. Everything else: fold it or cut it.

## Personal photos — never view without explicit approval

Never open, render, or otherwise look at Stanley's photographs without asking
first and getting an explicit yes. This covers camera originals (`.RAF`, `.JPG`,
`.DNG`, and any other raw or image format off his Fujifilm), anything derived
from them (extracted embedded previews, thumbnails, conversions, crops,
screenshots of them), and personal images anywhere on the machine — `~/Pictures`,
`~/Documents/camera`, Photos libraries, scratch dirs.

The rule is about *viewing*, not touching. These are all fine unasked: reading
metadata (`exiftool`, `mdls`, EXIF, headers), counting and listing files, moving
or converting or batch-processing them, checking dimensions and file sizes.
What needs approval is any step that puts actual pixels in front of the model —
the Read tool on an image file, a screenshot of one, an image-capable subagent
pointed at one.

Why it matters: viewing is not local. The Read tool on an image uploads that
image to Anthropic as part of the conversation. "Let me just check the render
looks right" is exactly the reasoning that leads to an unrequested upload of a
private photo — verify with metadata and pixel statistics instead, or ask.

If verifying visually is genuinely the only way, say so, say which specific file
and why, and wait for a yes. Do not batch the request ("can I look at a few") —
name the file.

## Commits

- Never add `Co-Authored-By: Claude ...` trailers to commit messages. No Claude attribution in git history, in any project. The commit message should end with the body — no attribution footer.

@RTK.md

## Record forge links (agent-link)

When you grab an issue or open a merge/pull request during a session, record it
so tmux hotkeys can open it from the pane: `agent-link issue <url>` /
`agent-link mr <url>` (`agent-link add mr <url>` for more). Run from inside
your worktree — it stores per-worktree metadata and tags the tmux pane. If the
command is missing, skip silently.

## Log papercuts

When you hit a small friction while working — a dead-end tool call, a broken
link, a confusing or undocumented setup step, a flaky command, a misleading
error, a non-obvious gotcha — log it: `papercut "<what got in the way>"`. One
or two sentences: what you were doing → what blocked you (a guess at the
cause/fix is a bonus). Do it in the moment, even though none of these block
you — logged together they show where the repo needs sanding down. Add
`-m <model>` to attribute it. Writes to `PAPERCUTS.md` at the repo root (`-g`
for the global file). Distinct from a work log (what you accomplished) and from
tracked bugs. If the command is missing, skip silently.
