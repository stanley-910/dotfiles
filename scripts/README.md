# Scripts

Custom utility scripts, split into two locations by purpose.

## `bin/` — global commands (on `$PATH`)

Added to `$PATH` directly from `zsh/.zshenv`:

```sh
export PATH="$HOME/dotfiles/scripts/bin:$PATH"
```

This points straight at the repo, so it is **not** stowed (see
`.stow-local-ignore`). To add a global command:

```sh
nvim ~/dotfiles/scripts/bin/mytool   # no extension → clean command name
chmod +x ~/dotfiles/scripts/bin/mytool
mytool                               # runnable from anywhere, no restow
```

Current: `afk-run`, `align`, `open-obsidian.sh`.

## `.config/scripts/` — config-invoked helpers (stowed)

Scripts called by full path from shell config rather than typed as commands —
e.g. `tmux-sessionizer` (bound to `^f` in `.zshrc`) and `.lessfilter` (used via
`$LESSOPEN`). Stowed to `~/.config/scripts/` like the rest of the package.

After adding a file here, re-establish the symlink:

```sh
stow --restow scripts   # run from ~/dotfiles
```

## `Library/LaunchAgents/` — launchd services

See [HEADROOM_PI_COPILOT.md](HEADROOM_PI_COPILOT.md) for the proxy's history,
launchd operations, health checks, and troubleshooting.

LaunchAgent plists are versioned here but ignored by Stow because `launchctl`
rejects them when installed as symlinks. Deploy the Headroom proxy plist as a
real file, then bootstrap it:

```sh
label=com.stanwang.headroom-proxy
plist="$HOME/Library/LaunchAgents/$label.plist"

launchctl bootout "gui/$UID/$label" 2>/dev/null || true
install -m 644 \
  "$HOME/dotfiles/scripts/Library/LaunchAgents/$label.plist" \
  "$plist"
launchctl bootstrap "gui/$UID" "$plist"
launchctl enable "gui/$UID/$label"
```

The Headroom job runs a bare `headroom proxy` on `127.0.0.1:8787` with the
request limiter disabled. Claude Code reaches it via `ANTHROPIC_BASE_URL` in
`claude/.claude/settings.json`; Pi reaches it through the `headroom` provider
in `pi/.config/pi/agent/models.json`. Both carry their own auth, so the proxy
holds no credentials. Restart it after a `headroom update`:

```sh
launchctl kickstart -k "gui/$UID/com.stanwang.headroom-proxy"
```
