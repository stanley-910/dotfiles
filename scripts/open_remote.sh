#!/usr/bin/env bash

# Open the current repository in the browser
dir=$(tmux display-message -p "#{pane_current_path}")
cd "$dir"
url=$(git remote get-url origin)
url_branch=$(git branch --show-current)
username='wangs3'


function main () {
  # Check if the repository is on GitHub or Autodesk
  if [[ $url == *"github.com"* ]] || [[ $url == *"git.autodesk.com"* ]]; then
    # Convert SSH URL to HTTPS if necessary
    if [[ $url == git@* ]]; then
      url=$(echo "$url" | sed 's/git@\(.*\):/https:\/\/\1\//')
    fi

    if [[ ! -z $url_branch ]]; then
      if [[ $url_branch != "master" && $url_branch != "main" ]]; then
        url=${url%.git} # rm git suffix if present
        if [[ $1 == "h" ]]; then
          url="$url/tree/$url_branch"
        elif [[ $1 == "H" ]]; then
          url="$url"
        elif [[ $1 == "p" ]]; then
          url="$url/pulls/$username"
        elif [[ $1 == "P" ]]; then
          # Extract JIRA ticket number if present in branch name
          if [[ $url_branch =~ (SG-[0-9]+) ]]; then
            ticket="${BASH_REMATCH[1]}"
            url="$url/pulls?q=is%3Aopen+is%3Apr+author%3A$username+$ticket"
          else
            echo "No JIRA ticket number (SG-XXXX) found in branch name: $url_branch"
            exit 1
          fi
        else
          echo "Invalid argument: $1"
          exit 1
        fi
      fi
    fi

    open "$url"
  else
    echo "This repository is not hosted on GitHub or Autodesk Git"
    exit 1
  fi

}


main "$@"