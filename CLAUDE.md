# Dotfiles

GNU Stow-managed dotfiles for macOS (Apple Silicon). Each top-level directory is a stow package.

## Pi agent defaults

- Claude-family Pi agents, such as `claude-opus-4.8`, use the `github-copilot` provider.
- All other Pi agents use `headroom-copilot` and the latest GPT model. The current default is `gpt-5.6-sol:high`.
- Parallel `github-copilot` launches can race while refreshing auth. Start those agents one at a time until each passes auth, then let them run concurrently. If a batch fails auth, retry it with sequenced launches.

## Commits

Stagger commits by stow package (the "tool") — one package per commit, never mix packages in a single commit. Use Conventional Commits with the package name as the scope: `feat(nvim): ...`, `fix(zsh): ...`, `chore(zed): ...`. When one package has unrelated changes, make separate focused commits, each still scoped to that package. (No `Co-Authored-By` trailers — see global CLAUDE.md.)

## Stow conventions

**Full directory stow** (`stow --restow -v <pkg>`):
cursor, fastfetch, ghostty, git, jetbrains, nvim, scripts, starship, sioyek, zsh

**Selective file stow** (`stow --restow --no-folding -v <pkg>`):
agents, claude, herdr, karabiner, lazygit, pi, tmux, yazi, zed

Use `--no-folding` when the app writes runtime data (plugins, extensions, backups, installed packages) into the same config directory. This prevents those files from being tracked.

**Not stowed:** `scripts/bin/` is excluded from stow via `scripts/.stow-local-ignore`. It's added to `$PATH` directly from `.zshenv` (`$HOME/dotfiles/scripts/bin`), so executables dropped there are globally runnable with no symlink and no restow. (`scripts/.config/scripts/` is still stowed normally for config-invoked helpers.)

## Package structure

- Home directory targets: `pkg/.filename` (e.g. `git/.gitconfig`)
- XDG config targets: `pkg/.config/appname/file` (e.g. `ghostty/.config/ghostty/config`)
- Home dot-directory targets: `pkg/.dirname/` (e.g. `agents/.agents/skills/`)

## Shell config split

- `.zshenv` — runs for ALL shells including non-interactive agent subshells. Contains: Homebrew, Cargo, Node, Python PATHs, EDITOR, API keys (env vars).
- `.zprofile` — runs for login shells only. Contains: interactive-session PATHs (IDE CLIs, GUI apps).
- `.zshrc` — runs for interactive shells. Contains: aliases, functions, plugins, completions, keybindings. No PATH exports here.

## Skills management

Every skill is an owned, version-controlled file — no `/install` and no `.skill-lock.json`. There is nothing to reconcile.

- **Shared hub** (`dotfiles/agents/.agents/skills/`, `agents` stow package, `--no-folding`) holds every agent-agnostic skill. It's the cross-agent source of truth: `~/.agents/skills/<name>/*` are stow symlinks into the repo, and consumers point back at the hub — `~/.claude/skills/<name>` → `../../.agents/skills/<name>`, and pi's `~/.config/pi/agent/skills/<name>` → `../../../../.agents/skills/<name>`.
- **Claude-only skills** (`dotfiles/claude/.claude/skills/`, `claude` stow package) are the few that lean on Claude-specific tooling (parallel Agent-tool sub-agents, etc.) — e.g. `code-review`, `codebase-design`, `orchestrate`. `~/.claude/skills/<name>/*` are per-file symlinks into that package.

A skill belongs in the hub unless it has genuine Claude quirks; grep a candidate for `Agent tool`/`subagent`/`Explore` before deciding. Do not replace `~/.claude/skills` with a directory symlink because shared child links must coexist with stowed Claude-only skills.

Every agent installing, updating, repairing, or auditing a skill must use `agents/.agents/skills/install-skill/scripts/install-skill` or its read-only `verify-skill` companion. These scripts enforce the source, Stow hub, Claude, and Pi location invariants. When the user supplies raw `SKILL.md` content, extract its frontmatter name, choose the scope, write the canonical source first, then run the installer by name; the scripts do not accept raw content or stdin. On a fresh machine, stow `agents` once to bootstrap the installer, then use it for each owned skill; pass `--scope claude` for Claude-only skills.

## Stow and symlinks

All config files are symlinked from `~/dotfiles/<pkg>/` into `$HOME` via GNU Stow. When editing files, always target the dotfiles source — the symlinks point back here. After adding new files to a stow package, re-run `stow --restow` (or `--adopt -R` if a real file already exists at the target) to establish symlinks. Agents making changes to stowed configs should verify symlinks are intact after file operations.

## Neovim coaching policy

When working on the `nvim` package, prefer a docs-first pair-programming flow. The goal is for Stanley to become able to configure Neovim/Lua with minimal agent help.

- Point to a bounded path of 2-4 relevant `:help` tags, in reading order, with what to look for and where to stop. Avoid sending Stanley down a full help-tag rabbit hole unless explicitly requested.
- Use pair mode: explain the implementation shape, let Stanley write or edit the obvious/simple parts when feasible, then review and help with the tricky seam.
- Gate custom Lua glue. Before implementing stateful Lua, autocmd-heavy behavior, or internal plugin API usage, state the complexity tier, the mechanism, a simpler alternative, and the ownership/fragility risk; ask before proceeding.
- Prefer native options, documented plugin settings, and simple keymaps before custom helpers. If custom helpers are used, give them clear names, add doc-anchor comments for non-obvious APIs, and keep a deletion/simplification path visible.
- Mark fragile code that touches plugin internals explicitly so it can be revisited after plugin updates.

## Secrets

API keys and tokens go in `~/.secrets/env` (sourced by `.zshenv`, never tracked).

## What NOT to track

- Secrets / API keys (put in `~/.secrets/env`)
- Plugin directories (`~/.tmux/plugins/`, `~/.config/yazi/plugins/`, `~/.config/zed/extensions/`)
- Auto-generated lock files (`Brewfile.lock.json`)
- Shell history, completion caches
- `.DS_Store` files
