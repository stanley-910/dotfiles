#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Dev Apps
# @raycast.mode compact

function is_app_running() {
    osascript -e "tell application \"System Events\" to (name of processes) contains \"$1\""
}

function is_app_visible() {
    local process_name="$1"
    osascript <<EOF
        tell application "System Events"
            tell process "$process_name"
                get visible
            end tell
        end tell
EOF
}

function toggle_app() {
    local app_name="$1"
    local process_name="$2"
    
    if [ "$(is_app_running "$process_name")" = "true" ]; then
        # App is running, check visibility and toggle
        if [ "$(is_app_visible "$process_name")" = "true" ]; then
            # Just hide without changing focus
            osascript <<EOF
                tell application "System Events"
                    tell process "$process_name"
                        set visible to false
                    end tell
                end tell
EOF
        else
            # Show and focus
            osascript <<EOF
                tell application "$app_name" to activate
                tell application "System Events"
                    tell process "$process_name"
                        set visible to true
                    end tell
                end tell
EOF
        fi
    else
        # App is not running, launch it and focus
        if [ -d "/Applications/$app_name.app" ]; then
            open -a "$app_name"
            # Wait a moment for the app to launch
            sleep 1
            osascript -e "tell application \"$app_name\" to activate"
        else
            echo "$app_name not found in /Applications"
            exit 1
        fi
    fi
}

# Toggle WebStorm
toggle_app "WebStorm" "WebStorm"

# Toggle Ghostty
toggle_app "Ghostty" "Ghostty" 