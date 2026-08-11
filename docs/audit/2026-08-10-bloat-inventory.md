# Bloat inventory — 2026-08-10

Full-repo stow-package audit. Gathered by an Explore subagent (Sonnet, very
thorough), load-bearing claims spot-verified by the driver session; one scout
error corrected inline (worktrunk). Companion to
`docs/audit/2026-08-internship-dossier.md` (independent re-verification, not a
copy). Action state lives in the session/board, not here.

## Package inventory

| Package | App/Tool | LOC (hand-written) | Installed? | Last commit | Flags |
|---|---|---|---|---|---|
| agents | Claude/Pi agent skills hub | ~12,580 | yes | 2026-08-10 | B, C |
| claude | Claude Code config/skills | ~1,650 | yes | 2026-08-10 | B (doc mention only) |
| cursor | Cursor editor | 34 | yes | 2026-08-05 | — |
| docs | repo docs | 573 | n/a | 2026-08-05 | — |
| fastfetch | system info fetcher | 122 | yes | 2026-04-13 | — |
| ghostty | terminal | 56 | yes | 2026-06-24 | TODO |
| git | git config | 101 | yes | 2026-07-11 | C (nbdime) |
| herdr | agent workspace mux | 122 | yes | 2026-08-05 | — |
| jetbrains | IdeaVim + IDE backups | 317 (+2 zips) | partial | 2026-08-05 | A (WebStorm) |
| karabiner | keyboard remapper | 23 (+1,320 GUI json) | yes | 2026-08-05 | C (dead app IDs) |
| lazygit | git TUI | 11 | yes | 2026-08-10 | — |
| nvim | Neovim (primary editor) | 11,673 | yes | 2026-08-10 | 6 TODOs |
| pi | Pi agent extensions | 5,061 | yes | 2026-08-10 | B (test fixtures, expected) |
| raycast | launcher | 7 (+binary) | yes | 2026-08-05 | — |
| scripts | bin/ + .config/scripts | 5,065 | mixed | 2026-08-10 | B, C, D |
| sioyek | PDF viewer | 121 | yes | 2026-04-12 | — |
| starship | prompt | 243 | yes | 2026-06-08 | — |
| tmux | multiplexer | 290 | yes | 2026-08-10 | C (fingers undeclared) |
| userscripts | browser userscripts | 168 | yes | 2026-08-10 | — |
| yazi | file manager | 89 | yes | 2025-12-18 | — |
| zed | Zed editor | 1,172 | yes | 2026-06-11 | — |
| zsh | shell rc | 857 | yes | 2026-08-05 | C ×3 |
| Brewfile | core CLI bootstrap | 130 | — | 2026-06-24 | all consumed |
| Brewfile.external | extra formulas/casks | 141 | — | 2026-08-10 | D ×3, TODO ×4 |

Flags: A = configures uninstalled app · B = work-era leftover · C = dead
reference · D = suspected unused · E = runtime litter.

## (A) Configures an uninstalled app

- `jetbrains/.config/jetbrains/webstorm/settings.zip` — WebStorm.app absent
  (verified `/Applications`; `~/Library/Application Support/JetBrains` has only
  IntelliJIdea2025.3 + PyCharm2025.3). README documents the stale *path*, but
  the app itself is gone.

## (B) Work-era leftovers

- `scripts/bin/fastrun-fire:30,92` — hardcodes `fastrun.china.online.ea.com`
  (EA regression system). Zero callers outside docs.
- `scripts/bin/fastrun-token` — keychain companion for the same EA token; zero
  callers.
- `scripts/.config/scripts/open_remote.sh:8,11,15,89` — `username='stanwang'`,
  Autodesk Jenkins base URL, `git.autodesk.com`/`gitlab.ea.com`/
  `gitlab.cs.mcgill.ca` matching. **Live** via `git-menu` (tmux `prefix+g`).
- `scripts/.config/scripts/open_ticket.sh:8,15` — `jira.autodesk.com`,
  `SG-XXXX` format. Also live via git-menu.
- `scripts/.config/scripts/organize-class-files:4` — McGill course organizer
  (MATH/COMP/PHIL/LING). Zero callers.
- `scripts/Library/LaunchAgents/com.stanwang.headroom-proxy.plist:6` +
  `scripts/HEADROOM_PI_COPILOT.md` — old-username launchd label, currently
  running; cosmetic; already tracked in `docs/MIGRATION.md:56`.
- `/Users/stanwang/...` hardcoded in skills: `pi-package-discovery`,
  `fujifilm-street-photo-coach` (SKILL.md:15,42 +
  `scripts/manual_visual_search.py:22`), `nvim-coach` (SKILL.md:16),
  `chrome-devtools-mcp`; also
  `claude/.claude/memory-archive/learn/leetcode-solutions-path.md:12`.
  `/Users/stanwang` does not exist.
- Prototype copies of open_remote/open_ticket under `scripts/prototypes/herdr/`
  duplicate the above refs but are a documented, bounded Herdr trial
  (`config.toml:82` points at them) — not bloat.

## (C) Dead references (verified against disk/PATH)

- `zsh/.zshenv:24` — Intel-Homebrew python PATH (`/usr/local/opt/python`
  absent). Verified dead.
- `zsh/.zshenv:35` — `~/.lmstudio/bin` PATH; LM Studio absent. Verified dead.
- `zsh/.zshrc:330` — `alias ws="open -a 'WebStorm.app' ."`; app absent.
- `git/.gitconfig:29-38` — nbdime diff/merge tool blocks; `git-nbdiffdriver`
  etc. not on PATH (verified), nbdime declared in no Brewfile.
- `tmux/.config/tmux/tmux.conf:227` — tmux-fingers plugin needs the
  `morantron/tmux-fingers` tap CLI; binary installed (verified) but declared
  in **neither Brewfile** — fresh-machine bundle silently breaks the binding
  (matches PAPERCUTS.md dylib entry).
- Dead vault path `.../Documents/codex-cloud/sources/fujifilm` in
  fujifilm-street-photo-coach + nvim-coach skills; real vault has only
  `notes-v1/` and `花园/`.
- `karabiner/karabiner.json` — app-conditional rules for
  `com.actualbudget.actual`, `com.google.Chrome`, `com.postmanlabs.mac`; none
  installed (verified). GUI-generated, harmless no-ops.

## (D) Suspected unused

- `Brewfile.external:47,50,67,69` — mpv / mole / worktrunk / hunk: already
  ticketed (#9). **Correction to scout:** worktrunk IS installed
  (`/opt/homebrew/bin/wt`, verified) — scout's "not installed" claim is wrong;
  `.zshrc:701` guard is live.
- `Brewfile.external:103` — `sqlite`: zero textual references in repo.
- `Brewfile.external:121` — `font-hack-nerd-font`: active ghostty font is
  `Berkeley Mono Def` (config:27, verified); no live consumer names it.
- `Brewfile.external:122` — `font-symbols-only-nerd-font`: also unnamed in
  configs, BUT symbols-only nerd fonts are typically consumed *implicitly* as
  the glyph-fallback for starship/eza icons — likely load-bearing despite
  zero grep hits. Driver recommendation: keep.
- `scripts/.config/scripts/open-dev-apps` — zero callers (no alias, keybind,
  Raycast ref) + toggles absent WebStorm. Sibling `open-dev-apps.sh` may be
  Raycast-invoked outside grep reach — lower confidence, check Raycast before
  cutting.

## (E) Runtime litter

- `.DS_Store` inside stow packages (cursor ×2, jetbrains ×2, scripts, root) —
  gitignored, but **stow doesn't read gitignore**: a restow symlinks them into
  `$HOME`.
- `karabiner/.config/karabiner/automatic_backups/karabiner_20260518.json` —
  app-generated backup inside the package; ignored but physical litter.
- In-flight (not litter): dirty `PAPERCUTS.md`, `claude/.claude/CLAUDE.md`,
  `claude/.claude/settings.json`; untracked `scripts/bin/raf2dng`.

## Minor backlog (not bloat)

TODO markers: nvim ×6 (autocmds, multicursor ×2, cursor, flash, quickbind,
leetcode), ghostty config:35. Two small intentional commented toggles in
`.zshrc:453-462` (zoxide cd) and `:643-654` (tmux auto-attach).
