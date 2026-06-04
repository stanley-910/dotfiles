# PATHs for login (interactive) shells only
# For agent-accessible PATHs, use .zshenv instead

# macOS /etc/zprofile runs path_helper AFTER .zshenv, which reorders system dirs
# (/usr/bin, etc.) ahead of our user bins. Re-prepend ~/.local/bin so uv's
# python/python3 shims win over system Python in login shells. (Non-login agent
# shells don't run path_helper, so .zshenv already handles them.)
export PATH="$HOME/.local/bin:$PATH"

# Obsidian
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"

# IntelliJ IDEA CLI
export PATH="$PATH:/Applications/IntelliJ IDEA.app/Contents/MacOS"

# Ghostty CLI (`ghostty +show-config`, etc.)
export PATH="$PATH:/Applications/Ghostty.app/Contents/MacOS"
