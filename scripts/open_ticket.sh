#!/usr/bin/env bash

# Open the current repository in the browser
dir=$(tmux display-message -p "#{pane_current_path}")
cd "$dir"
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