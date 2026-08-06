# Changelog

## 2026-08 — internship era (c5cad33 → mac HEAD)

This spans the from-scratch Neovim era and the agent-tooling era, audited in `docs/audit/2026-08-internship-dossier.md`.

### claude

- Added a selective-stow Claude package with global working preferences, delegation policy, keybindings, notifications, permissions, and a Starship-style status line.
- Added direct issue/MR commands, Herdr session reporting, standard worktree placement, and tldraw subagent integration.
- Added Claude-specific review, design, and orchestration skills alongside the archived interview-prep memory.

### root docs

- Added `CLAUDE.md` as the source of truth for package-scoped commits, Stow modes, shell PATH ownership, skill topology, Neovim coaching, and secret handling.
- Added `PAPERCUTS.md`, Pi coverage, project-local agent settings, broader runtime ignores, and clearer full-versus-selective Stow guidance; the old `setups/` documentation is gone.

### bootstrap & drift absorption

- Expanded `bootstrap.sh` and added `prepper.sh` for a fresh Mac: safer Stow conflict handling, XDG state, staged Homebrew/GUI setup, macOS defaults, Mos, SSH, and repo cloning. The legacy `setups/` scripts are gone.
- Rewrote `Brewfile.external` around adopted daily drivers including `gh`, `glab`, `lazygit`, `diff-so-fancy`, `worktrunk`, `hunk`, `go`, `uv`, `shellcheck`, `shfmt`, `httpie`, `mpv`, `mole`, `rtk`, and `tree-sitter-cli`.
- Pruned 24 stale declarations, including the Zathura stack, old build-chain and terminal-toy entries, superseded Python/package-manager versions, and the later `fluor` and `keycastr` casks.
- Codified the lived-in macOS keyboard repeat values as `KeyRepeat = 2` and `InitialKeyRepeat = 30`; the earlier 1/10 defaults were faster than wanted.
- Seeded Mos with its normalized values and documented the human-readable settings in `docs/mos.md`, because Mos rewrites its plist and otherwise looks like persistent drift.
- Fixed the drift audit to compare short Homebrew names for tap-qualified formulae such as `hunk`; these audit-absorption changes landed in `6751a10..07be232`.

### agents

- Added the `agents` Stow package as the owned shared-skill hub, growing to 36 skill directories with Claude and Pi consumer links enforced by `install-skill` and `verify-skill`.
- Added `forge` and `glab-board` for GitHub/GitLab issue lifecycle, blocking/frontier management, and issue/MR recording.
- Added engineering workflows for orchestration, TDD, diagnosis, triage, prototyping, domain modeling, research, specifications, tickets, and codebase teaching.
- Added personalized coaching and utility skills for interview prep, Neovim, shell, photography, ADHD-friendly output, tldraw, Chrome DevTools, Pi packages, writing, and context retention; the transient skill-lock model is gone.

### nvim

- Built the entire Neovim configuration from scratch, moving startup, options, keymaps, autocmds, commands, plugin loading, and LSP behavior into focused Lua modules.
- Added project and branch sessions, worktree switching, smart tmux-pane navigation, filetype-local behavior, and the QuickBind prototype.
- Added the custom Snacks dashboard, `mine` colorscheme, lualine components, Oil, Dropbar, Flash, WhichKey, Treewalker, and other navigation/UI tooling.
- Added Lua, Python, Go, and Java tooling through native LSP configuration, Mason, blink.cmp, LuaSnip, Conform, and filetype overrides.
- Added DAP, persistent breakpoints, local LeetCode debugging, Diffview, Gitsigns, Copilot ghost text, and in-package configuration documentation.

### pi

- Added the selective-stow Pi package with agent settings, model and MCP catalogs, Crew configuration, runtime ignores, and documentation.
- Added the local `headroom-copilot` provider and made high-thinking `gpt-5.6-sol` the default while expanding the available Copilot model catalog.
- Added the Starship-style status footer, Vim prompt editor, fenced-code copy selector, and inline slash completion, with focused regression tests.
- Added Forge completion, agent-link opening, Herdr blocked-question state, tldraw context injection, and global worker/worktree/tracker policies.

### herdr

- Added tmux-style workspace, tab, pane, copy-mode, zoom, and navigation bindings, plus agent-priority sorting, labeled borders, deep scrollback, and quiet Gruvbox UI defaults.
- Added LazyGit, git-menu, and reviewr plugin actions, with home-relative paths and package documentation.
- Herdr is **adopted**, graduating from its prototype/trial status rather than being removed.

### scripts

- Added `agent-link` and expanded git-menu/remote helpers to record, open, and copy issue, MR, PR, and worktree links.
- Added the Headroom Copilot proxy service and runbook, plus Fastrun regression helpers and Herdr workspace prototypes.
- Added media and transfer tools including `optimize-media`, video-to-GIF handling, and `sd-import`, with safer backups and normalized JPEG output.
- Added PATH-direct utilities such as `afk-run`, `align`, `papercut`, session cleanup, Obsidian opening, and Zed font sizing; Stow ignores now keep runtime/deployed files out of the package.

### zed

- Greatly expanded context-aware keymaps for the Agent panel, search, project navigation, code actions, completion, debugging, and file finding.
- Added Pi, Gemini, GitHub Copilot CLI, and Claude agent servers; switched edit prediction to Copilot and removed Context7.
- Changed fonts, panel/title-bar layout, diff presentation, language tooling, synchronized font-size tasks, and the custom dark theme.

### zsh

- Split shell ownership across `.zshenv` for all-shell paths and XDG state, `.zprofile` for login-only app paths, and `.zshrc` for interactive behavior; the hardcoded `/Users/stanley/.local/bin` path is gone.
- Moved history, completion, SDKMAN, Go, and Pi state toward XDG paths and sourced secrets from `~/.secrets/env`.
- Added model-tier Claude wrappers, an isolated Headroom Pi launcher, a full-permission Copilot wrapper, and Worktrunk shell integration.
- Tightened fzf-tab acceptance, vi-mode cursor handling, lazy SDKMAN/thefuck loading, `zmv`, and virtualenv helpers while dropping nvm/envman setup.

### zathura

- **Removed** the Zathura package, including its Vim-style reader configuration and installation/Stow documentation.
- Sioyek superseded it; the old `zathurarc` remains recoverable from history at `f3b2c2e~1`.

### sioyek

- Added Vim-like page, zoom, history, document, presentation, bookmark, highlight, fast-read, and visual-mark controls.
- Added dark separators/backgrounds, fast search, separate-window behavior, and Berkeley Mono UI/status fonts as the maintained PDF-reader setup.

### raycast

- Added the dated Raycast configuration export and placeholder.
- The opaque export is **kept as a backup**, not treated as a Stow-managed configuration package.

### jetbrains

- Added an IntelliJ settings archive covering editor, keymap, IdeaVim, plugins, JDK, terminal, and UI options.
- Expanded IdeaVim with corrected highlighted-yank support, NERDTree, text-object and exchange plugins, Dial transformations, IDE navigation, debugging, VCS, and run actions.
- Kept the settings archive as a restore artifact; its machine-specific Maven path is harmless because IntelliJ re-derives it on import.

### git

- Replaced the old work identity with Stanley's personal identity, made global ignores home-relative, selected Neovim as editor, enabled untracked cache, and set `main` as the default branch.
- Added nbdime notebook diff/merge integration and broadened global ignores for macOS, IDE, Vim, environment, Python, log, and local-agent artifacts.

### tmux

- Added focus events, path-based automatic window names, terminal title forwarding, and Ghostty true-color, cursor, and extended-key support.
- Added no-prefix smart pane navigation that cooperates with Vim/Neovim at pane edges.
- Added tmux-fingers URL/path actions, safer pane killing, a history split, and refined copy-mode, status, activity, window, and session behavior; the old agentic pane was removed.

### starship

- Moved identity, directory, branch, and Git status into the left prompt and emptied the right prompt.
- Added always-visible `m4p` hostname aliases, richer repository-path styling, styled Git state, and distinct normal/error/Vim prompt symbols.

### lazygit

- Added LazyGit as a selective-stow package using `diff-so-fancy` and automatic staging of resolved conflicts.
- Routed conflict editing through Neovim and Diffview so terminal Git work shares the main editor workflow.

### karabiner

- Added an `fn`-held numpad layer across the right-hand letter keys while retaining the Shift+Escape Caps Lock toggle and existing experiments.
- Kept selective Stow ownership so Karabiner's generated backups remain local.

### ghostty

- Changed themes, selected Berkeley Mono, tightened padding, disabled blur/opacity, preserved window state, and hid the mouse while typing.
- Disabled Ghostty cursor management so the Zsh vi-mode hook owns cursor shape and color without interference.

### fastfetch

- Fixed the malformed shell module label to render as ` Shell`.
- No module ordering, schema, hardware reporting, or other display behavior changed.

### cursor

- Cursor Vim behavior did not materially change; the only tracked edit was a trailing blank line.
- Kept `macos.code-profile` as a backup despite stale machine paths, following the Raycast-export precedent.
