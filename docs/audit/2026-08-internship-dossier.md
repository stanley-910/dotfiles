# Internship dotfiles audit dossier — 2026-08

Per-package state diff `c5cad33` (2025-12-18, "update zed theme") → `HEAD`, with
portability tags, convention checks, and **draft** verdicts. Verdicts are drafts:
Stanley adjudicates them in the next wayfinder ticket
(`.wayfinder/internship-dotfiles-sync/tickets/05-adjudicate-audit-verdicts.md`).

**Method.** 309 commits since baseline. Six read-only scout workers
(`headroom-copilot/gpt-5.6-sol:high` via the Pi harness) each drafted the
sections for one package slice from `git diff`/`git log` and HEAD file state;
the driver verified every claim behind a non-keep verdict inline (marked
*Driver note* where the verification added nuance).

**Portability tags** — `portable`: works on a personal Mac as-is.
`work-only`: depends on EA network/tooling. `adapt-needed`: keep, but strip or
replace named markers.

## Summary

| Package | Portability | Draft verdict |
|---|---|---|
| claude | adapt-needed | keep |
| root-docs | adapt-needed | broken-fix-needed |
| bootstrap | portable | broken-fix-needed |
| agents | adapt-needed | keep |
| nvim | portable | broken-fix-needed |
| pi | adapt-needed | keep |
| herdr | portable | ~~drop~~ **keep** (adjudicated 2026-08-05) |
| scripts | adapt-needed | broken-fix-needed |
| zed | portable | keep |
| zsh | adapt-needed | keep |
| zathura | portable | **drop** (adjudicated 2026-08-05) |
| sioyek | portable | keep |
| raycast | portable | ~~drop~~ **keep** (adjudicated 2026-08-05) |
| jetbrains | adapt-needed | broken-fix-needed |
| git | portable | keep |
| tmux | portable | keep |
| starship | adapt-needed | keep |
| lazygit | portable | keep |
| karabiner | portable | keep |
| ghostty | portable | keep |
| fastfetch | portable | keep |
| cursor | adapt-needed | broken-fix-needed |

**Adjudication complete (Stanley, 2026-08-05):** every remaining draft verdict was
locked as drafted; the six broken-fix-needed entries carry their agreed fix in an
*Adjudicated* line in their section. Portability tags confirmed (13 portable,
9 adapt-needed, 0 work-only) — they scope the personal-substitutes ticket and the
migration strip list.

## Sections

### claude

- **Changed**:
  - Added the selective-stow `claude/.claude/` package with global working preferences, delegation policy, RTK guidance, keybindings, and a Starship-style status line.
  - Added `claude/.claude/settings.json` with model, permission, skill-visibility, notification, Herdr, and tldraw subagent-hook configuration.
  - Added `claude/.claude/commands/issue.md` and `claude/.claude/commands/mr.md` for opening forge links without model mediation.
  - Added `claude/.claude/hooks/herdr-agent-state.sh` for session reporting and `hooks/worktree-create.sh` for worktree placement.
  - Added Claude-only `code-review`, `codebase-design`, and `orchestrate` skills, including design deepening and orchestrator report references.
  - Added archived personal memory for `intern-assassin` and interview/LeetCode learning paths.
  Notable commits:
  a8878bf chore(claude): pin fable-5 model and add tldraw-offline subagent hook
  256d1c6 feat(claude): add Herdr session integration
  2f67948 feat(claude): own codebase-design
  dfa37cc feat(claude): add Claude-adapted orchestrate skill
  467291c feat(claude): add /mr and /issue slash commands + MR auto-record hook
- **Portability**: adapt-needed — Exact markers are `gitlab.ea.com` in `claude/.claude/CLAUDE.md:16`, `headroom-copilot`/Copilot-fleet routing in `CLAUDE.md:79-84`, `DELEGATION.md:1-80`, and `skills/orchestrate/SKILL.md:133-139`, `127.0.0.1:8787` plus `/Users/stanwang/...` PATH/hook entries in `settings.json:3-4,70`, and `/Users/stanwang/.local/share/nvim/leetcode/` in `memory-archive/learn/leetcode-solutions-path.md:12`.
- **Conventions**: OK
- **Draft verdict**: keep — the package matches the documented selective-stow and Claude-only-skill layout, with machine/work assumptions that should be adapted when copied elsewhere.

### root-docs

- **Changed**:
  - Added root `CLAUDE.md` covering package-scoped commits, full/selective Stow lists, shell PATH ownership, skill topology/install rules, Neovim coaching, and secret handling.
  - Added `PAPERCUTS.md` and populated it with local tooling, context-mode, shell, Pi/Copilot, tldraw, and delegation friction records.
  - Added project-local `.claude/settings.json`, enabling `dotfiles-drift` and disabling background worktree isolation.
  - Expanded `.gitignore` for project-local Claude state, Karabiner runtime files, RPIV/context-mode output, Pi schedules/session HTML, and Crew runtime directories while retaining selected Crew placeholders.
  - Updated `README.md` with Pi Coding Agent coverage, separate full/selective Stow commands, the current `scripts/` entry, and `--no-folding` pollution guidance; removed the legacy `setups/` tree reference.
  Notable commits:
  0570720 docs: document Pi agent provider defaults and install-skill workflow
  2182597 Absorb 37 tooling/swarm papercuts from madden-agent
  62b4494 chore(dotfiles): manage project-local agent state
  26efa1e docs: switch skills management to the owned-only model
  4dd5630 docs(repo): update stow package documentation
- **Portability**: adapt-needed — Exact markers are `headroom-copilot` in `CLAUDE.md:8`, `/Users/stanwang/...` in the historical papercut at `PAPERCUTS.md:55`, `gitlab.ea.com` in the historical papercut at `PAPERCUTS.md:84`, and `_headroom-copilot/claude-opus-4.8_` at `PAPERCUTS.md:106`; no `127.0.0.1:8787`, `api.githubcopilot.com`, or `/Users/stanwang/EA` marker is present.
- **Conventions**:
  - `README.md:94,103` omit documented full-stow package `herdr`; `README.md:97,106,185` omit documented selective-stow package `lazygit`.
  - `README.md:144` documents obsolete `zathura/` instead of the authoritative `sioyek` package.
  - `SETUP_NOTES.md:22-29` retains the old Stow split, including `zathura` and omitting `herdr`, `nvim`, `sioyek`, `agents`, `claude`, `lazygit`, and `pi`.
- **Draft verdict**: broken-fix-needed — authoritative conventions are useful, but the README and setup notes give stale package lists.
  **Adjudicated (Stanley, 2026-08-05):** fix README stow lists in apply-verdicts (add `herdr`, `lazygit`; swap `zathura`→`sioyek`); `SETUP_NOTES.md` is decided once, in the migration-guide ticket.

### bootstrap

- **Changed**:
  - Updated `Brewfile` to move Ghostty, Karabiner-Elements, Zed, and Cursor GUI installation to stage 1 and changed the optional Node formula from `node@20` to `node`.
  - Updated `Brewfile.external` from `node@20` to the unversioned `node` formula.
  - Expanded `bootstrap.sh` with realpath-safe Stow-conflict backups, XDG state directories, separate full/selective Stow arrays, selective Pi stowing, and shared-skill consumer links.
  - Added the 432-line `prepper.sh` stage-1 fresh-Mac flow for Homebrew, Claude Code, GUI casks, Helium/default-browser shortcuts, macOS defaults, Mos, GitHub SSH setup, and repo cloning.
  - Removed the legacy `setups/setup_zsh.sh` script and the `setups/` directory from HEAD.
  Notable commits:
  0949464 chore(dotfiles): use unversioned Homebrew node formula
  3ba869e feat(prepper): add Helium navigation shortcuts
  730d123 fix(bootstrap): stow pi with no-folding
  0ebea46 chore(bootstrap): create XDG state dirs, clarify ~/.local/bin
  c6ec080 chore: remove legacy setups/ directory
- **Portability**: portable — No `headroom-copilot`, `gitlab.ea.com`, `/Users/stanwang/EA`, `api.githubcopilot.com`, Copilot-fleet, `127.0.0.1:8787`, work-hostname, or hardcoded machine-specific `/Users/...`/`/home/...` marker is present at HEAD.
- **Conventions**:
  - `bootstrap.sh:244` omits documented full-stow package `herdr`; `bootstrap.sh:248` omits documented selective-stow package `lazygit`.
  - `bootstrap.sh:308-339` manually creates Claude/Cursor skill symlinks instead of using the required `agents/.agents/skills/install-skill/scripts/install-skill` workflow and does not establish the documented Pi consumer invariant itself.
- **Draft verdict**: broken-fix-needed — the bootstrap is otherwise portable, but its package arrays and skill-link setup have drifted from root `CLAUDE.md`.
  **Adjudicated (Stanley, 2026-08-05):** sync the stow arrays with `CLAUDE.md` (add `herdr`, `lazygit`) and replace the hand-rolled skill-symlink block with a loop over `install-skill`.

### agents

- **Changed**:
  - Added the `agents` Stow package as an owned shared-skill hub at `agents/.agents/skills/`; the net diff is 97 added files spanning 36 skill directories, with no modified or deleted baseline files.
  - Added `forge/` with `scripts/glab-board`, tests, reference docs, GitHub/GitLab board setup, lifecycle labels, blocking/frontier handling, and issue/MR recording workflows.
  - Added `install-skill/` with `install-skill`, `verify-skill`, and shared shell helpers to enforce canonical source, Stow hub, Claude, and Pi consumer-link invariants; the transient `.skill-lock.json` approach was removed during the range.
  - Added orchestration and engineering workflows including `orchestrate/`, `tdd/`, `diagnose/`, `triage/`, `prototype/`, `domain-modeling/`, `research/`, `to-spec/`, `to-tickets/`, and `trace-and-teach/`.
  - Added coaching and personalized skills including `interview-prep-coach/`, `nvim-coach/`, `shell-coach/`, `fujifilm-street-photo-coach/`, and `i-have-adhd/`, with supporting references, scripts, templates, and one PDF asset.
  - Added utility/integration skills including `tldraw-offline/`, `chrome-devtools-mcp/`, `pi-package-discovery/`, `humanizer/`, `caveman/`, `remember-context/`, and `writing-great-skills/`.
Notable commits:
9cf8ab2 add agents stow package with custom skills
819d6f2 feat(agents): vendor 10 skills as owned, drop stale lock entries
58e0d8e feat(agents): automate Forge issue lifecycle
c87920d feat(agents): add install-skill skill
48092aa feat(agents): add tldraw-offline skill
- **Portability**: adapt-needed — `agents/.agents/skills/forge/docs/platform-agnostic-scoping.md:112` names `gitlab.ea.com`, while Chrome DevTools, Fujifilm, Neovim, Pi package discovery, and shell coaching files contain hardcoded `/Users/stanwang/...` or `/Users/stanley/...` paths (for example `chrome-devtools-mcp/SKILL.md:18` and `shell-coach/SKILL.md:15`).
- **Conventions**: OK
- **Draft verdict**: keep — this is the canonical shared-skill source and matches the documented Stow hub layout, but its user-specific and EA references need adaptation on another personal Mac.

### nvim

- **Changed**:
  - Added the full `nvim/.config/nvim/` configuration from scratch: all 81 paths in `c5cad33..HEAD` are additions, with no tracked modifications or removals relative to the baseline.
  - Added modular startup and editor behavior in `init.lua` and `lua/config/{options,keymap,autocmds,commands,lazy,lsp}.lua`, including smart tmux-pane navigation and filetype-local behavior.
  - Added native project/branch sessions and worktree switching in `lua/config/sessions.lua`, plus the QuickBind action/editor prototype in `quickbind*.lua`.
  - Added a custom Snacks dashboard in `lua/config/dashboard.lua`, a `mine` Lush colorscheme, lualine components, and UI/navigation plugins including Oil, Dropbar, Flash, WhichKey, and Treewalker.
  - Added language tooling for Lua, Python, Go, and Java through `lsp/*.lua`, Mason, blink.cmp, LuaSnip, Conform, and nine `after/ftplugin/*.lua` overrides.
  - Added debugging and review workflows through DAP, persistent project breakpoints, LeetCode local debugging, Diffview, Gitsigns, Copilot ghost text, and extensive documentation in `.config/nvim/README.md`.
  Notable commits:
  6e07ab5 add nvim from scratch first commit
  23670f0 feat(nvim): overhaul LSP setup (blink, mason, pyright, ruff)
  d7b2869 feat(nvim): expand plugin tooling and add project sessions
  b982184 feat(nvim): setup custom dashboard
  ad6fb2c feat(nvim): add Go and Java language support
- **Portability**: portable — no `headroom-copilot`, `gitlab.ea.com`, `/Users/stanwang/EA`, `api.githubcopilot.com`, `copilot fleet`, `127.0.0.1:8787`, work hostname, or hardcoded machine-specific absolute-path marker is present at HEAD.
- **Conventions**:
  - `nvim/issues.md:1` sits at the full-directory stow package root, so `stow --restow nvim` targets it as `~/issues.md` instead of placing it under the documented `nvim/.config/nvim/` XDG tree.
- **Draft verdict**: broken-fix-needed — keep the configuration, but move `nvim/issues.md` into the XDG config tree or explicitly exclude it from stow before restowing.
  **Adjudicated (Stanley, 2026-08-05):** move it to `nvim/.config/nvim/issues.md` — it documents the config and belongs inside it.

### pi

- **Changed**:
  - Added the selective-stow Pi package scaffolding: `pi/.config/pi/agent/settings.json`, `models.json`, `mcp.json`, `pi/.pi/agent/pi-crew.json`, `.stow-local-ignore`, and `README.md`.
  - Added a `headroom-copilot` model provider backed by `http://127.0.0.1:8787/v1`, expanded its Copilot model catalog, and made `gpt-5.6-sol` with high thinking the default.
  - Added the large `extensions/starshipline/index.ts` status footer and `extensions/vim-editor/index.ts` Vim-style prompt editor, including motion and registration-order regression tests.
  - Added `extensions/copy-selector/` for selecting fenced code blocks and `extensions/inline-slash-completion/` for slash-command completion, each with focused tests.
  - Added `extensions/forge-autocomplete/`, `extensions/agent-link.ts`, and `extensions/herdr-question-state.ts` for forge reference completion, session issue/MR opening, and Herdr blocked-question reporting.
  - Added `extensions/tldraw-context/` for injecting offline tldraw server context, plus global `AGENTS.md` policies for workers, worktrees, tracker safety, skill installation, and papercut logging.

Notable commits:
17269a1 docs(pi): document headroom default model and new starshipline behavior
11303f9 feat(pi): add tldraw-context extension
a842955 feat(pi): rework starshipline footer layout
fc73376 feat(pi): add inline slash completion
db43598 feat(pi): add vim prompt editor

- **Portability**: adapt-needed — runtime defaults contain `headroom-copilot` and `127.0.0.1:8787`, while `gitlab.ea.com` appears only in `forge-autocomplete` test fixtures; no `/Users/stanwang/EA`, `api.githubcopilot.com`, Copilot-fleet, or hardcoded `/Users/...` path was found.
- **Conventions**:
  - `pi/.config/pi/agent/models.json:6` tracks a literal `apiKey` value (`headroom-local`) rather than sourcing credentials from `~/.secrets/env`.
    *Driver note: verified — the value is a sentinel the local Headroom proxy ignores, not a real credential; a leak risk of zero, but it normalizes tracked apiKey fields, so still worth adjudicating.*
- **Draft verdict**: keep — this is the active, documented Pi setup; a personal Mac must run the local Headroom proxy or override the default provider, and the tracked local API-key sentinel should be adjudicated.
  **Adjudicated (Stanley, 2026-08-05):** keep the `headroom-local` sentinel tracked as-is; add one `pi/README.md` line stating it's a proxy sentinel, not a credential, so nobody "fixes" it into `~/.secrets/env`.

### herdr

- **Changed**:
  - Added `herdr/.config/herdr/config.toml` as a throwaway multiplexer evaluation with tmux-style prefix, workspace, tab, pane, copy-mode, zoom, and navigation bindings.
  - Added UI/runtime choices for copy-on-select, one-line mouse scrolling, agent-priority sorting, pane-border labels, 10 MB scrollback, Gruvbox, disabled toasts, and disabled sound.
  - Added command bindings for `lazygit`, the home-relative `~/dotfiles/scripts/prototypes/herdr/git-menu`, and the `persiyanov.reviewr.toggle` plugin action.
  - Added `plugins/config/persiyanov.reviewr/config.toml` with zoomed toggle placement and `README.md` with run/removal instructions and explicit prototype scope.

Notable commits:
28105c8 feat(herdr): expand keybindings, add reviewr plugin command keys
5fd0382 feat(herdr): multiplexer evaluation config

- **Portability**: portable — no `headroom-copilot`, EA/GitLab, Copilot endpoint/fleet, localhost proxy, work-hostname, or hardcoded `/Users/...` marker was found; paths are `~`-relative, though `~/dotfiles` and the separately installed `~/.local/bin/herdr` are assumed.
- **Conventions**:
  - `herdr/README.md:30` tells users to unstow with `--no-folding`, but repo `CLAUDE.md` documents `herdr` as a full-directory stow package.
- **Draft verdict**: drop — the package declares itself a throwaway evaluation (`config.toml` header: "PROTOTYPE — evaluate Herdr before adopting").
  *Driver note: the scout's README-vs-config `git-menu` contradiction is stale — the binding was documented in the ticket-01 commits; the drop rationale rests on the self-declared prototype status alone.*
  **Adjudicated (Stanley, 2026-08-05): keep.** Herdr has graduated from trial to adopted package. Apply-verdicts follow-ups: remove the PROTOTYPE disclaimer from `config.toml`, reconcile `herdr/README.md`'s `--no-folding` unstow instruction with CLAUDE.md's full-stow listing, and reframe the trial-scoped removal instructions.

### scripts

- **Changed**:
  - Added `scripts/bin/agent-link` and expanded `.config/scripts/git-menu`/`open_remote.sh` to record, open, and copy agent issue/MR/worktree links, including numeric issue and MR/PR lookup.
  - Added the Headroom Copilot proxy stack: `bin/headroom-pi-copilot`, `Library/LaunchAgents/com.stanwang.headroom-proxy.plist`, and the detailed `HEADROOM_PI_COPILOT.md` runbook.
  - Added media tooling: `bin/optimize-media`, `bin/optimize-media-setup`, and `.config/scripts/vid-to-gif.sh`, with later fixes for video handling, backup protection, and JPEG 4:2:0 output.
  - Added work regression helpers `bin/fastrun-fire` and `bin/fastrun-token`, plus `bin/sd-import` for SD-card transfer.
  - Added general utilities `bin/afk-run`, `align`, `claude-wipe-session`, `open-obsidian.sh`, `papercut`, and `zed-font-size`.
  - Added `prototypes/herdr/` variants of the link/menu/remote/ticket helpers and documented the Herdr tmux binding.
  - Enhanced `.config/scripts/organize-class-files` with explicit-file input, regex filtering, conflict incrementing, and batch subject detection.
  - Added `.stow-local-ignore` and updated `README.md` so `scripts/bin` stays PATH-direct while the launchd plist is deployed as a real file rather than a Stow symlink.
  Notable commits:
  4aa75e9 feat(scripts): add Headroom Copilot proxy service
  ce60bcd feat(scripts): add Fastrun regression helpers
  5962981 feat(scripts): add optimize-media, Clop-faithful media optimizer
  50ffd15 feat(scripts): add agent-link forge-link recorder + git-menu m/i/y keys
  1a30053 feat(scripts): prototype Herdr-aware workspace helpers
- **Portability**: adapt-needed — `scripts/bin/fastrun-fire:30` uses the work hostname `fastrun.china.online.ea.com`, `.config/scripts/open_remote.sh:15` and its Herdr prototype match `gitlab.ea.com`, Autodesk Jenkins/Jira hostnames remain in the remote/ticket helpers, `HEADROOM_PI_COPILOT.md` uses `headroom-copilot` and `127.0.0.1:8787`, and `Library/LaunchAgents/com.stanwang.headroom-proxy.plist:9-39` hardcodes `/Users/stanwang` paths.
- **Conventions**:
  - `scripts/HEADROOM_PI_COPILOT.md:1` is a non-dot top-level Stow source not excluded by `.stow-local-ignore`, so full-directory Stow installs an undocumented `~/HEADROOM_PI_COPILOT.md` target.
  - `scripts/prototypes/herdr/README.md:1` (and sibling prototype scripts) lives outside `bin/` and `.config/` and is not ignored, so full-directory Stow creates the undocumented `~/prototypes/herdr/` target.
    *Driver note: verified latent — neither `~/HEADROOM_PI_COPILOT.md` nor `~/prototypes/` exists yet; both would appear on the next `stow --restow scripts`.*
- **Draft verdict**: broken-fix-needed — retain the useful scripts, but exclude or relocate the top-level Headroom runbook and `prototypes/` tree before restowing the package.
  **Adjudicated (Stanley, 2026-08-05):** add both `HEADROOM_PI_COPILOT.md` and `prototypes/` to `scripts/.stow-local-ignore`; no relocation.

### zed

- **Changed**:
  - `zed/.config/zed/keymap.json` was heavily expanded (375 additions, 179 removals) with context-specific Agent panel, search navigation, project panel, code-action, completion, debugger, and file-finder bindings.
  - `zed/.config/zed/settings.json` added registry Agent servers for Pi ACP, Gemini, GitHub Copilot CLI, and Claude ACP, while switching edit predictions to Copilot and removing Context7.
  - Editor settings now use Berkeley Mono/Prose, 15-point UI and buffer fonts, a split diff view, revised panels/title bar, and language-specific Ruff/BasedPyright/Typst configuration.
  - `zed/.config/zed/tasks.json` adds hidden `zed-font-size` increase/decrease tasks, wired to Cmd-plus/minus variants so all Zed font sizes move together.
  - `zed/.config/zed/themes/custom-theme.json` adds a 62-line dark custom theme, and `zed/README.md` now documents Agent-panel and search keybinding precedence.

  Notable commits:
  a5a0307 chore(zed): reduce editor and agent font sizes
  4509f9e feat(zed): refine search and agent keybindings
  c75fdfd feat(zed): link zoom keys to all font sizes
  9371052 chore(zed): use copilot edit predictions, refresh agent servers, drop context7
  5d880bd feat(zed): add value-jump, code-action, and visual/markdown file-finder keymaps
- **Portability**: portable — none of the listed work endpoints, Copilot fleet markers, localhost proxy, work hostnames, or hardcoded `/Users/...` paths appear in tracked Zed files.
- **Conventions**: OK
- **Draft verdict**: keep — the package remains in the documented selective-stow layout and contains reusable editor configuration.

### zsh

- **Changed**:
  - Added `zsh/.zshenv` to centralize all-shell PATH setup, XDG directories, SDKMAN/Go/Pi state locations, history paths, editor variables, and sourcing of `~/.secrets/env`.
  - Added `zsh/.zprofile` for login-only application paths covering Obsidian, IntelliJ IDEA, Ghostty, and the `~/.local/bin` path-helper correction.
  - `zsh/.zshrc` removed its old hardcoded `/Users/stanley/.local/bin` PATH export and reorganized interactive-only plugins, completion caching, highlighting, history, and Ghostty integration.
  - Added Claude model-tier wrappers, a full-permission Copilot CLI wrapper, and `hpi`, which launches Pi from an ephemeral copied config against the Headroom Copilot provider.
  - Added safer fzf-tab acceptance rules, XDG history sharing, vi-mode cursor hooks, SDKMAN/thefuck lazy loading, `zmv`, virtualenv helpers, and `wt` shell integration.

  Notable commits:
  74c806f feat(zsh): init wt shell integration when available
  43a1c19 feat(zsh): add isolated Headroom Pi launcher
  a2e6dec feat(zsh): route SDKMAN, Go, and history dirs through XDG paths
  3d6ca1b feat(zsh): XDG history persistence and headroom claude wrapper
  7df1f7b feat(zsh): vi-mode cursor via zle hooks; drop nvm/envman, lazy thefuck
- **Portability**: adapt-needed — `zsh/.zshrc:408-409` hardcodes `headroom-copilot/gpt-5.6-sol` and the `headroom-copilot/*` model fleet in the optional `hpi` launcher.
- **Conventions**: OK
- **Draft verdict**: keep — general shell setup is correctly split across `.zshenv`, `.zprofile`, and `.zshrc`; only the opt-in Headroom launcher needs personal-Mac adaptation.

### zathura

- **Changed**:
  - Deleted `zathura/.config/zathura/zathurarc`, removing its Vim navigation, clipboard, fit/scroll, recoloring, font, and window-size configuration.
  - Deleted `zathura/README.md`, including its Homebrew tap/install and `~/.config/zathura` stow instructions.
  - No tracked files remain under `zathura/` at HEAD, and the package was removed from the root stow-package lists.

  Notable commits:
  f3b2c2e clean up configs, remove zathura, secure API key handling
  fdccc8d some updates
- **Portability**: portable — the package has no files at HEAD, so none of the listed work or machine-specific markers remain.
- **Conventions**: OK
- **Draft verdict**: drop — the package was intentionally removed and has no HEAD state to preserve.
  **Adjudicated (Stanley, 2026-08-05): drop confirmed.** Superseded by sioyek; the old `zathurarc` stays recoverable from history at `f3b2c2e~1`.

### sioyek

- **Changed**:
  - Added `sioyek/.config/sioyek/keys_user.config` with Vim-like page movement, zoom, history, document, presentation, and window bindings.
  - Added bookmark/highlight navigation and editing keys, plus fast-read, status-bar, visual-mark, and highlight-type controls.
  - Added `sioyek/.config/sioyek/prefs_user.config` with black page separators/backgrounds, super-fast search, separate-window behavior, and Berkeley Mono UI/status fonts.

  Notable commits:
  6462c14 add sioyek stow package
  c5cad33 update zed theme
- **Portability**: portable — no listed work endpoints, Copilot provider markers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — this is a clean XDG-layout replacement PDF-viewer package documented in the full-stow list.

### raycast

- **Changed**:
  - Added an empty `raycast/.gitkeep` placeholder.
  - Added `raycast/Raycast 2026-05-19 09.56.40.rayconfig`, a dated 1,085,232-byte opaque binary Raycast export.
  - Added no README or text configuration explaining import, restore, ownership, or stow behavior.

  Notable commits:
  7f6d2b3 feat(raycast): add raycast backup
  c5cad33 update zed theme
- **Portability**: portable — no listed markers were visible in printable strings, although the opaque binary export cannot be fully text-audited.
- **Conventions**:
  - `CLAUDE.md:18-21` omits `raycast` from both documented stow modes.
  - `raycast/Raycast 2026-05-19 09.56.40.rayconfig:1` is a non-dot binary at package root, outside the documented home-dot/XDG target shapes.
- **Draft verdict**: drop — this is an undocumented backup artifact rather than a stowable configuration package.
  **Adjudicated (Stanley, 2026-08-05): keep.** The export stays in the repo as a backup. Apply-verdicts follow-ups: add a README documenting export/import (not stowed), and consider refreshing the May snapshot.

### jetbrains

- **Changed**:
  - Added `jetbrains/.config/jetbrains/intellij/settings.zip`, a 53,693-byte IntelliJ settings archive containing editor, keymap, IdeaVim, plugin, JDK, terminal, and UI options.
  - `jetbrains/.ideavimrc` fixed the `highlightedyank` spelling and enabled NERDTree, paragraph-motion, anyobject, Dial, and vim-exchange integrations.
  - Added Dial increment/decrement mappings and transformation groups for numbers, dates, Java, Python async, and Markdown task items.
  - Reworked movement and insert mappings, IDE action bindings, symbol/declaration navigation, search, debugging, recent-location, VCS, and run actions.
  - The new IntelliJ archive embeds `MAVEN_REPOSITORY=/Users/stanley/.m2/repository` in `options/path.macros.xml` content.

  Notable commits:
  be79889 update intellij
  718d488 sync uncommitted changes from mac working directory
  134cbee update some keybinds
  25fb67a update tmux, jetbrains, zed
- **Portability**: adapt-needed — the new IntelliJ archive contains the hardcoded machine path `/Users/stanley/.m2/repository`; no EA/Copilot work endpoints were found.
- **Conventions**:
  - `jetbrains/.config/jetbrains/.ideavimrc:1` is an undocumented duplicate target; `jetbrains/README.md:21` documents only `~/.ideavimrc`.
  - `jetbrains/README.md:27` prescribes built-in Settings Sync, but the tracked IntelliJ/WebStorm settings archives and their restore location are undocumented.
- **Draft verdict**: broken-fix-needed — retain the IdeaVim config, but reconcile the duplicate target and sanitize/document the settings archives before keeping them.
  **Adjudicated (Stanley, 2026-08-05):** delete the duplicate `jetbrains/.config/jetbrains/.ideavimrc` (diff against the home-dot one first, merge if diverged); keep the settings archives and document them in the README; leave the `/Users/stanley/.m2` path macro inside the zip — harmless, IntelliJ re-derives it on import.

### git

- **Changed**:
  - `git/.gitconfig` replaced the old Autodesk identity with Stanley's personal name/email and changed the global excludes path from `/Users/stanley/...` to `~/.gitignore_global`.
  - Added Neovim as Git's editor, untracked-cache support, and `main` as the default initial branch.
  - Added nbdime notebook diff/difftool/mergetool integration while leaving the custom merge driver commented out.
  - `git/.gitignore_global` now covers macOS metadata, IDE files, Vim swaps, environment files, Python artifacts, logs, `Thumbs.db`, and Claude local settings.

  Notable commits:
  c628fed fix(bootstrap): removed user specific paths, updated some other things
  f3b2c2e clean up configs, remove zathura, secure API key handling
  dafbcc4 nvim git msg editor
- **Portability**: portable — the old absolute `/Users/stanley/.gitignore_global` path was removed, and no listed work endpoints, work hostnames, or machine-specific absolute paths remain.
- **Conventions**: OK
- **Draft verdict**: keep — the home-dot stow layout is correct and the package now uses portable paths and personal Git defaults.

### tmux

- **Changed**:
  - `tmux/.config/tmux/tmux.conf` added focus events, automatic window renaming from `pane_current_path`, title forwarding, and Ghostty true-color/cursor/CSI-u terminal features.
  - Added extended-key handling and corrected Option+Shift bindings to explicit `M-S-*` forms.
  - Added smart no-prefix Ctrl+Shift pane navigation that passes through to Vim/Neovim and falls back to tmux at editor edges.
  - Added tmux-fingers plugin configuration, quick URL/path actions, a history-view split, and safer two-step pane-kill handling.
  - Refined copy-mode search, activity/bell styling, status placement, plugin path initialization, and several window/session bindings.

  Notable commits:
  04fec1f feat(tmux): add smart Neovim pane navigation
  e0a84ed feat(tmux): add tmux-fingers quick bindings
  5f1fda1 refactor(tmux): clean up option-key window navigation binds
  0da9137 fix(tmux): forward cursor colour and style to outer terminal
- **Portability**: portable — no listed work endpoints, Copilot providers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — the selective-stow location is correct and the changes are reusable terminal behavior rather than host-specific state.

### starship

- **Changed**:
  - `starship/.config/starship.toml` moved username, hostname, directory, Git status, and Git branch into the left prompt and emptied the right prompt.
  - Added always-visible hostname rendering with aliases for `Mac` and `Stanleys-MacBook-Pro`, both displayed as `m4p`.
  - Expanded directory styling to distinguish repository root, path, pre-root path, and read-only state.
  - Enabled styled Git-status output and changed normal/error/Vim prompt symbols to `$`, `$`, and `:` respectively.

  Notable commits:
  841e261 feat(starship): move git info into left prompt
  718d488 sync uncommitted changes from mac working directory
- **Portability**: adapt-needed — `starship/.config/starship.toml:74` hardcodes the machine hostnames `Mac` and `Stanleys-MacBook-Pro` as aliases to `m4p`.
- **Conventions**: OK
- **Draft verdict**: keep — the prompt is valid full-stow configuration; another machine only needs to customize or remove the hostname aliases.

### lazygit

- **Changed**:
  - Added `lazygit/.config/lazygit/config.yml` as a new selective-stow package config.
  - Configured `diff-so-fancy` as the pager and automatic staging of resolved conflicts.
  - Configured terminal editing through `nvim -c DiffviewOpen {{filename}}` for conflict/merge work with the user's Neovim setup.

  Notable commits:
  ecc6c3c feat(lazygit): track LazyGit config
  c5cad33 update zed theme
- **Portability**: portable — no listed work endpoints, Copilot providers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — the file is in the documented XDG/selective-stow location and contains reusable LazyGit behavior.

### karabiner

- **Changed**:
  - `karabiner/.config/karabiner/karabiner.json` added a ten-key numpad layer mapping `u/i/o`, `j/k/l`, `m/,/.`, and `n` to digits 7-0 while `fn` is held.
  - The new rule's description says “hold left_option,” but every added manipulator actually requires the `fn` modifier.
  - Retained and evolved the Shift+Escape Caps Lock toggle, disabled modifier experiments, profile/device settings, and existing complex modifications.
  - The package remains a selective stow so Karabiner automatic backups stay local.

  Notable commits:
  3b052b7 feat(karabiner): add fn-held numpad layer on u/i/o j/k/l m/,/. keys
  56ffcbb shift + esc = caps
  2f72024 adopt karbiner
- **Portability**: portable — no listed work endpoints, Copilot providers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — the config is in the documented selective-stow target; only the numpad rule description should be corrected to say `fn`.
  **Adjudicated (Stanley, 2026-08-05):** keep; fold the description fix ("hold left_option" → `fn`) into apply-verdicts.

### ghostty

- **Changed**:
  - `ghostty/.config/ghostty/config` switched from `IC Orange PPL` to `Black Metal (Bathory)` and reduced horizontal padding from 6 to 5.
  - Disabled background blur/opacity styling and added always-save window state plus mouse hiding while typing.
  - Selected `Berkeley Mono Def` while retaining several alternative font/theme choices as comments.
  - Added `shell-integration-features = no-cursor` so the Zsh vi-mode cursor hook controls cursor shape and color without Ghostty interference.

  Notable commits:
  e94cfdd style(ghostty): tune theme and padding
  41927e6 feat(ghostty): switch to gruvbox theme
  11b23c4 fix(ghostty): disable shell-integration cursor management
- **Portability**: portable — no listed work endpoints, Copilot providers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — this remains a correctly located full-stow terminal config with no work-network dependency.

### fastfetch

- **Changed**:
  - `fastfetch/.config/fastfetch/config.jsonc` changed the shell module label from the malformed `hell` to ` Shell`.
  - No module ordering, display formatting, schema, or hardware reporting behavior changed.
  - `fastfetch/README.md` and the rest of the package are unchanged in the range.

  Notable commits:
  f3b2c2e clean up configs, remove zathura, secure API key handling
  c5cad33 update zed theme
- **Portability**: portable — no listed work endpoints, Copilot providers, work hostnames, localhost proxy, or hardcoded `/Users/...` paths were found.
- **Conventions**: OK
- **Draft verdict**: keep — the package is in the documented full-stow XDG layout and the only change fixes a display label.

### cursor

- **Changed**:
  - `cursor/.config/cursor/.cursorvimrc` gained only a trailing blank line after `nnoremap <S-CR> ciW`.
  - No Cursor Vim mapping or behavior changed since `c5cad33`.
  - `cursor/.config/cursor/macos.code-profile` and `cursor/README.md` are unchanged in the range, but remain part of the HEAD package state.

  Notable commits:
  7b60bc2 restow karabine
  c5cad33 update zed theme
- **Portability**: adapt-needed — `cursor/.config/cursor/macos.code-profile:1` embeds repeated `/Users/stanley/Developer/...` workspace/file-history paths, including `testing-ground` and `stanley-wang` projects.
- **Conventions**:
  - `cursor/README.md:16` documents only `.cursorvimrc`, while the tracked 221,623-byte `macos.code-profile` backup and its restore role are undocumented.
- **Draft verdict**: broken-fix-needed — keep the Vim config, but sanitize or remove the machine-specific profile export before treating the package as portable.
  **Adjudicated (Stanley, 2026-08-05):** keep `macos.code-profile` as a documented backup (raycast precedent) — README gets an import note plus a "contains stale machine paths, harmless" caveat; no sanitizing.
