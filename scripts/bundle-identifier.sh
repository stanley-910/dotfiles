#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Bundle ID
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "App Name" }
# @raycast.packageName App Bundle ID

# Documentation:
# @raycast.description Get bundle id for any app installed

osascript -e 'id of app "'"$1"'"'
