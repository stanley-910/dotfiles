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

# Python
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# pipx / user local binaries
export PATH="$HOME/.local/bin:$PATH"

# Custom scripts — points straight at the dotfiles repo (NOT stowed, see
# scripts/.stow-local-ignore). Drop an executable in dotfiles/scripts/bin and
# it's globally runnable immediately, no restow needed.
export PATH="$HOME/dotfiles/scripts/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Silence zoxide doctor warning in non-interactive shells
export _ZO_DOCTOR=0

# Keep history dotfiles out of $HOME — relocate to XDG state dir.
# (zsh's own HISTFILE lives in .zshrc with the rest of the history settings.)
export LESSHISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/less/history"
export PYTHON_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/python/history"

# Pi Coding Agent — move global config/state out of ~/.pi for XDG compliance.
# Keep this in .zshenv so interactive Pi sessions and non-interactive agent
# subshells agree on the same runtime directories.
export PI_CODING_AGENT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent"
export PI_CODING_AGENT_SESSION_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pi/sessions"

# Source local secrets (API keys, tokens) — not tracked by git
[[ -f ~/.secrets/env ]] && source ~/.secrets/env
