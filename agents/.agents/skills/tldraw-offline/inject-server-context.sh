#!/bin/sh
# Emit running tldraw server context for Claude/Codex agent hooks.
set -eu

event=${1:-SubagentStart}
server_json="${TLDRAW_SERVER_JSON:-$HOME/Library/Application Support/tldraw/server.json}"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$server_json" ] || exit 0

port=$(jq -r '.port // empty' "$server_json" 2>/dev/null) || exit 0
token=$(jq -r '.token // empty' "$server_json" 2>/dev/null) || exit 0
[ -n "$port" ] && [ -n "$token" ] || exit 0

context="The tldraw desktop canvas server is running at http://localhost:$port. Send the header 'Authorization: Bearer $token' on every request except GET / and /readme. Use these values directly — you do not need to read server.json."

docs=""
if command -v curl >/dev/null 2>&1; then
  docs=$(curl -s --max-time 2 -X POST "http://localhost:$port/api/search" \
    -H 'content-type: text/plain' \
    -H "authorization: Bearer $token" \
    --data-binary 'return await api.getDocs()' 2>/dev/null | jq -c '.result // empty' 2>/dev/null) || docs=""
fi

if [ -n "$docs" ] && [ "$docs" != "[]" ]; then
  context="$context

The user's currently open tldraw offline canvases (most-recently-active first): $docs"
fi

jq -n --arg event "$event" --arg context "$context" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $context}}'
