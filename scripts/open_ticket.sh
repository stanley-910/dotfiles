#!/usr/bin/env bash

# Open the current repository in the browser
dir=$(tmux display-message -p "#{pane_current_path}")
cd "$dir"
url_branch=$(git branch --show-current)

# Extract JIRA ticket number (SG-XXXX) from branch name
if [[ $url_branch =~ (SG-[0-9]+) ]]; then
    ticket="${BASH_REMATCH[1]}"
    url="https://jira.autodesk.com/browse/$ticket"
    open "$url"
else
    echo "No JIRA ticket number (SG-XXXX) found in branch name: $url_branch"
    exit 1
fi
