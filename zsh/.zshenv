# Environment variables and PATHs available to ALL shells
# (including non-interactive agent subshells like Claude Code, OpenCode)

# Keep $PATH entries unique. zsh ties the `path` array to $PATH; -U dedupes it
# automatically, so re-prepends (e.g. .zprofile after macOS path_helper) and
# nested login shells never accumulate duplicate entries.
typeset -U path PATH

export EDITOR=nvim
export VISUAL=nvim

# Homebrew (Apple Silicon)
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

# Cargo (Rust) — only if installed via rustup
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Node.js is provided by Homebrew's unversioned /opt/homebrew/bin/node.
# Avoid prepending versioned node@XX formula paths here; they can shadow upgrades.

# pipx / user local binaries
export PATH="$HOME/.local/bin:$PATH"

# Custom scripts — points straight at the dotfiles repo (NOT stowed, see
# scripts/.stow-local-ignore). Drop an executable in dotfiles/scripts/bin and
# it's globally runnable immediately, no restow needed.
export PATH="$HOME/dotfiles/scripts/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Silence zoxide doctor warning in non-interactive shells
export _ZO_DOCTOR=0

# XDG Base Directory — set explicitly so XDG-aware tools (lazygit, etc.) resolve
# to ~/.config, ~/.local/share, ~/.local/state, and ~/.cache instead of macOS's
# ~/Library/Application Support or top-level dotdirs. Must be actual exports;
# ${XDG_*:-...} fallbacks below don't set them for child processes.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# SDKMAN — keep SDKMAN's install/state out of ~/.sdkman. The interactive
# `sdk` shell function is sourced from .zshrc, not here.
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

# Go — keep the toolchain's user files out of ~/go and macOS Application Support.
# Homebrew owns the `go` binary under /opt/homebrew; `go install` drops command
# binaries in ~/.local/bin, which is already on PATH above.
export GOPATH="$XDG_DATA_HOME/go"
export GOBIN="$HOME/.local/bin"
export GOMODCACHE="$GOPATH/pkg/mod"
export GOCACHE="$XDG_CACHE_HOME/go-build"
export GOENV="$XDG_CONFIG_HOME/go/env"

# Keep history dotfiles out of $HOME — relocate to XDG state dir.
# (zsh's own HISTFILE lives in .zshrc with the rest of the history settings.)
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"

# Pi Coding Agent — move global config/state out of ~/.pi for XDG compliance.
# Keep this in .zshenv so interactive Pi sessions and non-interactive agent
# subshells agree on the same runtime directories.
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
export PI_CODING_AGENT_SESSION_DIR="$XDG_STATE_HOME/pi/sessions"



# iCloud Drive Vault path
export VAULT=$HOME/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/花园

# Source local secrets (API keys, tokens) — not tracked by git
[[ -f ~/.secrets/env ]] && source ~/.secrets/env
