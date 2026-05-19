# Environment variables and PATHs available to ALL shells
# (including non-interactive agent subshells like Claude Code, OpenCode)

export EDITOR=nvim
export VISUAL=nvim

# Homebrew (Apple Silicon)
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

# Cargo (Rust) — only if installed via rustup
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Node.js (Homebrew)
export PATH="/opt/homebrew/opt/node@20/bin:$PATH"

# Python
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# pipx / user local binaries
export PATH="$HOME/.local/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Silence zoxide doctor warning in non-interactive shells
export _ZO_DOCTOR=0

# Source local secrets (API keys, tokens) — not tracked by git
[[ -f ~/.secrets/env ]] && source ~/.secrets/env
