#!/bin/sh
# cc-talk-stop — Claude Code Stop hook: hand the finished reply to the speaker.
#
# Enabled by `talk`, disabled by `gag` (both in ~/dotfiles/scripts/bin). This
# runs at the end of every turn, so the flag check is the very first thing it
# does and every other path is silent-and-exit-0: a Stop hook that errors,
# prints, or blocks would show up as a stall on every single turn.
#
# The flag is per-session — one file per Claude Code session under
# ~/.claude/cc-talk/on/ — so enabling one session leaves the others silent.
# `on/global` is the explicit machine-wide opt-in. The legacy machine-wide
# ~/.claude/talk-on is ignored here; `talk`/`gag` delete it when they see it.
#
# It also records which tmux pane each session lives in, under
# ~/.claude/cc-talk/panes/, so the C-S-Space key can act on the session in the
# pane you are standing in. That map is written on every turn, enabled or not.
#
# Hooks run under `sh -c` with only Claude Code's launch env — nothing from
# .zshrc/.zshenv exists here. `jq` (/opt/homebrew/bin) and `cc-talk-speak`
# (~/dotfiles/scripts/bin) are reachable via settings.json "env.PATH".
set -u

state_dir="$HOME/.claude/cc-talk"
on_dir="$state_dir/on"
pane_dir="$state_dir/panes"

payload=""

# Which tmux pane is this session living in? Only this hook can answer that:
# the claude process inherits TMUX_PANE from its launch pane and passes it
# down, while its session id exists only in this payload. `talk cycle --pane`
# reads the map back, which is how one tmux key can act on the session in the
# pane you are standing in rather than on whatever happens to be speaking.
#
# It runs before the enabled check because a session has to be mappable
# *before* it is on — enabling from the key is the whole point.
if [ -n "${TMUX_PANE:-}" ] && command -v jq >/dev/null 2>&1; then
	payload=$(cat 2>/dev/null)
	pane_session=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
	pane_key=$(printf '%s' "$TMUX_PANE" | sed 's/[^A-Za-z0-9._-]/_/g')
	if [ -n "$pane_session" ] && mkdir -p "$pane_dir" 2>/dev/null; then
		# Panes are recycled and sessions die unannounced, so entries go stale.
		# Sweeping only when a pane is first seen keeps the common turn down to
		# the one write, and a new pane is exactly when the old ones are worth
		# doubting.
		[ -e "$pane_dir/$pane_key" ] ||
			find "$pane_dir" -type f -mtime +2 -exec rm -f {} + 2>/dev/null || true
		printf '%s\n' "$pane_session" >"$pane_dir/$pane_key" 2>/dev/null || true
	fi
fi

# Fast path, and the common one: nothing is enabled anywhere, so exit before
# spawning anything more. Globbing costs no processes.
enabled=0
for f in "$on_dir"/*; do
	[ -e "$f" ] && { enabled=1; break; }
done
[ "$enabled" = 1 ] || exit 0

# Nothing downstream can speak — don't read stdin, don't litter a temp file.
command -v jq >/dev/null 2>&1 || exit 0
command -v cc-talk-speak >/dev/null 2>&1 || exit 0

# Under tmux the pane map already drained stdin; stdin is a one-shot pipe, so
# reading it twice would come back empty.
[ -n "$payload" ] || payload=$(cat 2>/dev/null)
[ -n "$payload" ] || exit 0

# Which session just finished a turn? `talk` names its flag file after this
# same id, applying the same transform.
session_id=${pane_session:-}
[ -n "$session_id" ] || session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$session_id" ] || exit 0
key=$(printf '%s' "$session_id" | sed 's/[^A-Za-z0-9._-]/_/g')

# Some session is enabled, but is it this one?
[ -e "$on_dir/$key" ] || [ -e "$on_dir/global" ] || exit 0

message=$(printf '%s' "$payload" | jq -r '.last_assistant_message // empty' 2>/dev/null)
[ -n "$message" ] || exit 0

mkdir -p "$state_dir/disclosed" 2>/dev/null || exit 0

# The speaker takes a file rather than stdin so it can self-daemonize and
# still get the whole message; it unlinks the file once it has read it.
tmp=$(mktemp "$state_dir/msg.XXXXXX" 2>/dev/null) || exit 0
printf '%s\n' "$message" >"$tmp" 2>/dev/null || { rm -f "$tmp"; exit 0; }
cc-talk-speak --file "$tmp" >/dev/null 2>&1 || true

# Once per session, tell the user their reply just left the machine. The full
# policy was printed by `talk`; this is only the reminder.
marker="$state_dir/disclosed/$key"
[ -e "$marker" ] && exit 0
: >"$marker" 2>/dev/null || exit 0

printf '%s\n' '{"systemMessage":"🔊 cc-talk: reply sent to OpenAI TTS (see talk --help for the policy)"}'
exit 0
