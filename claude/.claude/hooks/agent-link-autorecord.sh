#!/usr/bin/env bash
# PostToolUse(Bash) hook: when a command created an MR/PR (glab mr create /
# gh pr create), record its URL via agent-link against the session's worktree.
# Recording must never break the session: fail open, always exit 0.
set -uo pipefail

AGENT_LINK="$HOME/dotfiles/scripts/bin/agent-link"
[[ -x "$AGENT_LINK" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0
case "$cmd" in
*"glab mr create"* | *"gh pr create"*) ;;
*) exit 0 ;;
esac

# The created MR/PR URL appears in the command output.
url=$(jq -r '.tool_response | tostring' <<<"$input" 2>/dev/null |
  grep -oE 'https?://[^"[:space:]\\]+/(-/)?(merge_requests|pull)/[0-9]+' |
  head -1)
[[ -n "$url" ]] || exit 0

cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)

# Commands often carry their own target ("cd <worktree> && glab mr create…");
# that beats the session cwd — record where the MR was actually made.
if [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+(\"([^\"]+)\"|\'([^\']+)\'|([^[:space:]\;\&]+))[[:space:]]*(\&\&|\;) ]]; then
  t="${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
  t="${t/#\~/$HOME}"
  [[ -d "$t" ]] && cwd="$t"
fi

[[ -d "$cwd" ]] || exit 0

(cd "$cwd" && "$AGENT_LINK" add mr "$url") >/dev/null 2>&1 || true
exit 0
