# Dotfiles

GNU Stow-managed dotfiles for macOS (Apple Silicon). Each top-level directory is a stow package.

## Commits

Stagger commits by stow package (the "tool") — one package per commit, never mix packages in a single commit. Use Conventional Commits with the package name as the scope: `feat(nvim): ...`, `fix(zsh): ...`, `chore(zed): ...`. When one package has unrelated changes, make separate focused commits, each still scoped to that package. (No `Co-Authored-By` trailers — see global CLAUDE.md.)

## Stow conventions

**Full directory stow** (`stow --restow -v <pkg>`):
cursor, fastfetch, ghostty, git, jetbrains, karabiner, nvim, scripts, starship, zathura, zsh, sioyek, claude

**Selective file stow** (`stow --restow --no-folding -v <pkg>`):
tmux, yazi, zed, agents

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

Custom skills live in `dotfiles/agents/.agents/skills/` (tracked via `agents` stow package with `--no-folding`).
Model-specific directories symlink back: `~/.claude/skills/<name>` → `../../.agents/skills/<name>`.

Installed skills (from `/install`) are managed by `.skill-lock.json`, which is also stowed and tracked.
On a fresh machine: `stow --no-folding agents`, then `/install` to reconcile from the lock file.

## Stow and symlinks

All config files are symlinked from `~/dotfiles/<pkg>/` into `$HOME` via GNU Stow. When editing files, always target the dotfiles source — the symlinks point back here. After adding new files to a stow package, re-run `stow --restow` (or `--adopt -R` if a real file already exists at the target) to establish symlinks. Agents making changes to stowed configs should verify symlinks are intact after file operations.

## Secrets

API keys and tokens go in `~/.secrets/env` (sourced by `.zshenv`, never tracked).

## What NOT to track

- Secrets / API keys (put in `~/.secrets/env`)
- Plugin directories (`~/.tmux/plugins/`, `~/.config/yazi/plugins/`, `~/.config/zed/extensions/`)
- Auto-generated lock files (`Brewfile.lock.json`)
- Shell history, completion caches
- `.DS_Store` files
