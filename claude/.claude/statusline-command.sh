#!/bin/sh
# Claude Code status line - mirrors Starship prompt style
input=$(cat)

# User and host
user=$(whoami)
host=$(hostname -s | sed 's/Stanleys-MacBook-Pro/m4p/; s/Mac/m4p/')

# Directory (truncate to last 3 parts, shorten home to ~)
cwd=$(echo "$input" | jq -r '.cwd')
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")
# Keep last 3 path components
short_cwd=$(echo "$short_cwd" | awk -F'/' '{
  n = NF
  if (n <= 3) { print $0 }
  else { print $(n-2) "/" $(n-1) "/" $n }
}')

# Git branch (skip lock issues by using --no-optional-locks)
git_branch=""
if git_out=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null); then
  if [ -n "$git_out" ]; then
    git_branch=" $git_out"
  fi
fi

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // empty')

# Context usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_info=""
if [ -n "$used_pct" ]; then
  ctx_info=" ctx:$(printf '%.0f' "$used_pct")%"
fi

# Session (5-hour rate limit) usage
sess_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
sess_info=""
if [ -n "$sess_pct" ]; then
  sess_info=" sess:$(printf '%.0f' "$sess_pct")%"
fi

# Compose output with ANSI colors (dimmed-friendly)
printf "\033[1;33m%s\033[0m\033[90m@\033[0m\033[90m%s:\033[0m\033[38;5;110m%s\033[0m" \
  "$user" "$host" "$short_cwd"

if [ -n "$git_branch" ]; then
  printf "\033[38;5;139m%s\033[0m" "$git_branch"
fi

if [ -n "$model" ]; then
  printf "\033[90m  %s\033[0m" "$model"
fi

if [ -n "$ctx_info" ]; then
  printf "\033[90m%s\033[0m" "$ctx_info"
fi

if [ -n "$sess_info" ]; then
  printf "\033[90m%s\033[0m" "$sess_info"
fi

printf "\n"
