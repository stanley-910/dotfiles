#!/bin/sh
# cc-talk-message — banks the turn so the Stop hook can speak all of it.
#
# Stop's `last_assistant_message` is the turn's *final* text by design, so
# everything said before a tool call — "I'll check the config first" — was never
# spoken. MessageDisplay fires as each assistant message is displayed, mid-turn,
# and is the only hook that is handed that text; this script writes each message
# into a per-session buffer that cc-talk-stop.sh drains.
#
# Registered on two events and dispatched on hook_event_name:
#   MessageDisplay   — append this message to the buffer
#   UserPromptSubmit — truncate the buffer (a new prompt means a new turn; Stop
#                      does not fire on interrupt, so this is the only reliable
#                      "forget the old fragments" signal)
#
# Verified payload (claude -p --model haiku, 2026-08-10):
#   {"session_id":…,"turn_id":…,"message_id":…,"index":0,"final":true,
#    "delta":"<the whole message text>"}
# It fired once per completed message, and `delta` carried that message in full
# — a 966-character paragraph arrived in a single fire, not in chunks. `final`
# and `index` exist for a streaming variant that was not observed, so this hook
# is written to survive one anyway: only `final` fires are banked, and a repeat
# fire for a message_id/index already held replaces that entry rather than
# stacking a duplicate.
#
# Subagent text never reaches here — a finished Task reports back as a
# `<task-notification>` UserPromptSubmit in the parent session, so there is no
# subagent-origin message to filter out.
#
# Like the Stop hook, every path is silent-and-exit-0. This runs on every
# assistant message, so an error or a stray stdout line would be noise on every
# turn — and on UserPromptSubmit, stdout would be injected into the prompt.
set -u

state_dir="$HOME/.claude/cc-talk"
on_dir="$state_dir/on"
turn_dir="$state_dir/turns"

# Fast path, and the common one: nothing is enabled anywhere, so exit before
# spawning anything. This hook fires far more often than Stop does, and
# globbing costs no processes.
enabled=0
for f in "$on_dir"/*; do
	[ -e "$f" ] && { enabled=1; break; }
done
[ "$enabled" = 1 ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat 2>/dev/null)
[ -n "$payload" ] || exit 0

# One pass for every field that steers the rest. None of these can contain a tab
# or a newline, so they survive @tsv; `delta` is read separately because it is
# free-form and multi-line.
meta=$(printf '%s' "$payload" |
	jq -r '[.session_id // "", .hook_event_name // "", (.final|tostring), .message_id // "", ((.index // 0)|tostring)] | @tsv' 2>/dev/null)
[ -n "$meta" ] || exit 0

old_ifs=$IFS
IFS='	'
read -r session_id event final message_id index <<EOF
$meta
EOF
IFS=$old_ifs

[ -n "$session_id" ] || exit 0

# `talk` names its flag file after this same id, applying the same transform.
key=$(printf '%s' "$session_id" | sed 's/[^A-Za-z0-9._-]/_/g')

# Some session is enabled, but is it this one?
[ -e "$on_dir/$key" ] || [ -e "$on_dir/global" ] || exit 0

buf="$turn_dir/$key"

if [ "$event" = "UserPromptSubmit" ]; then
	# Buffers outlive their session when talk is switched off mid-turn: Stop
	# bows out before it can drain one. Sweeping only when this session has no
	# buffer yet keeps the common turn down to the one unlink, and a session's
	# first prompt is exactly when the old buffers are worth doubting.
	[ -e "$buf" ] ||
		find "$turn_dir" -type f -mtime +2 -exec rm -f {} + 2>/dev/null || true
	rm -f "$buf" 2>/dev/null || true
	exit 0
fi

# Only completed messages are banked. A streaming variant would fire partial
# deltas with final=false; those are noise, because the final fire carries the
# message in full. An absent `final` is treated as complete.
[ "$final" = "false" ] && exit 0

# `select` drops messages that displayed no text at all (a tool-only message),
# so a blank record never reaches the speaker.
record=$(printf '%s' "$payload" |
	jq -c --arg k "$message_id:$index" 'select((.delta // "") != "") | {k: $k, t: .delta}' 2>/dev/null)
[ -n "$record" ] || exit 0

mkdir -p "$turn_dir" 2>/dev/null || exit 0

# Cheap insurance against a streaming variant that re-fires a message: replace
# the entry we already hold for it instead of speaking it twice.
if [ -s "$buf" ]; then
	last_key=$(tail -n 1 "$buf" 2>/dev/null | jq -r '.k // empty' 2>/dev/null)
	if [ "$last_key" = "$message_id:$index" ]; then
		tmp="$buf.tmp"
		if sed '$d' "$buf" >"$tmp" 2>/dev/null; then
			mv "$tmp" "$buf" 2>/dev/null || rm -f "$tmp" 2>/dev/null
		else
			rm -f "$tmp" 2>/dev/null
		fi
	fi
fi

printf '%s\n' "$record" >>"$buf" 2>/dev/null || true
exit 0
