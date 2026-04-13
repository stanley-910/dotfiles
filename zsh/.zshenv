# Environment variables and PATHs available to ALL shells
# (including non-interactive agent subshells like Claude Code, OpenCode)

export EDITOR=nvim
export VISUAL=nvim

# Homebrew (Apple Silicon)
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

# Cargo (Rust)
. "$HOME/.cargo/env"

# Node.js (Homebrew)
export PATH="/opt/homebrew/opt/node@20/bin:$PATH"

# Python
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# pipx / user local binaries
export PATH="$HOME/.local/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# API keys (rotate via Context7 dashboard, then update here)
# export CONTEXT7_API_KEY=""
