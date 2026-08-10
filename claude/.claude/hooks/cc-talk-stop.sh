#!/bin/sh
# cc-talk-stop — Claude Code Stop hook: hand the finished reply to the speaker.
#
# Enabled by `talk`, disabled by `gag` (both in ~/dotfiles/scripts/bin). This
# runs at the end of every turn, so the flag check is the very first thing it
# does and every other path is silent-and-exit-0: a Stop hook that errors,
# prints, or blocks would show up as a stall on every single turn.
#
# Hooks run under `sh -c` with only Claude Code's launch env — nothing from
# .zshrc/.zshenv exists here. `jq` (/opt/homebrew/bin) and `cc-talk-speak`
# (~/dotfiles/scripts/bin) are reachable via settings.json "env.PATH".
set -u

flag="$HOME/.claude/talk-on"
[ -f "$flag" ] || exit 0

# Nothing downstream can speak — don't read stdin, don't litter a temp file.
command -v jq >/dev/null 2>&1 || exit 0
command -v cc-talk-speak >/dev/null 2>&1 || exit 0

state_dir="$HOME/.claude/cc-talk"
mkdir -p "$state_dir/disclosed" 2>/dev/null || exit 0

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

message=$(printf '%s' "$payload" | jq -r '.last_assistant_message // empty' 2>/dev/null)
[ -n "$message" ] || exit 0

# The speaker takes a file rather than stdin so it can self-daemonize and
# still get the whole message; it unlinks the file once it has read it.
tmp=$(mktemp "$state_dir/msg.XXXXXX" 2>/dev/null) || exit 0
printf '%s\n' "$message" >"$tmp" 2>/dev/null || { rm -f "$tmp"; exit 0; }
cc-talk-speak --file "$tmp" >/dev/null 2>&1 || true

# Once per session, tell the user their reply just left the machine. The full
# policy was printed by `talk`; this is only the reminder.
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$session_id" ] || exit 0
marker="$state_dir/disclosed/$(printf '%s' "$session_id" | sed 's/[^A-Za-z0-9._-]/_/g')"
[ -e "$marker" ] && exit 0
: >"$marker" 2>/dev/null || exit 0

printf '%s\n' '{"systemMessage":"🔊 cc-talk: reply sent to OpenAI TTS (see talk --help for the policy)"}'
exit 0
