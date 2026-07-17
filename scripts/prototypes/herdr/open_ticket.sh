#!/usr/bin/env bash

# Herdr prototype. The production tmux helper remains untouched.
herdr_pane_path() {
  if [[ -n "${HERDR_ACTIVE_PANE_CWD:-}" ]]; then
    printf '%s\n' "$HERDR_ACTIVE_PANE_CWD"
    return 0
  fi

  local pane json path
  pane=${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}
  if [[ -n "$pane" ]]; then
    if [[ -n "${HERDR_BIN_PATH:-}" ]]; then
      json=$("$HERDR_BIN_PATH" pane get "$pane" 2>/dev/null || true)
    elif command -v herdr >/dev/null 2>&1; then
      json=$(herdr pane get "$pane" 2>/dev/null || true)
    fi
    if [[ -n "${json:-}" ]]; then
      path=$(printf '%s' "$json" | python3 -c '
import json, sys
pane = json.load(sys.stdin)["result"]["pane"]
print(pane.get("foreground_cwd") or pane.get("cwd") or "")
' 2>/dev/null || true)
      if [[ -n "$path" ]]; then
        printf '%s\n' "$path"
        return 0
      fi
    fi
  fi
  pwd
}

dir=$(herdr_pane_path)
cd "$dir" || exit 1
url_branch=$(git branch --show-current)

board_url="https://jira.autodesk.com/secure/RapidBoard.jspa?rapidView=13921&quickFilter=115105#"

# Extract JIRA ticket number (SG-XXXX) from branch name
function main () { 
    if [[ $1 == "j" ]]; then 
        if [[ $url_branch =~ (SG-[0-9]+) ]]; then
            ticket="${BASH_REMATCH[1]}"
            url="https://jira.autodesk.com/browse/$ticket"
            open "$url"
        else
            echo "No JIRA ticket number (SG-XXXX) found in branch name: $url_branch"
            exit 1
        fi
    elif [[ $1 == "J" ]]; then
        open "$board_url"
    else
        echo "Invalid argument: $1"
        exit 1
    fi
}

main "$@"