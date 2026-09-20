# dictate

Config and launchd agent for the `dictate` hotkey transcription daemon
(source: `~/Developer/dictate`). Selective stow:

    stow --restow --no-folding -v dictate

- `~/.config/dictate/config.json` — hotkey, mode, model path, replacement table.
- `~/Library/LaunchAgents/cc.stanleywang.dictate.plist` — starts the app at login.

Toggle the service:

    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/cc.stanleywang.dictate.plist
    launchctl bootout gui/$(id -u)/cc.stanleywang.dictate
