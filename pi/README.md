# Pi

Pi Coding Agent config managed by GNU Stow.

This package is stowed into XDG-compliant Pi paths. `zsh/.zshenv` exports:

```zsh
export PI_CODING_AGENT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent"
export PI_CODING_AGENT_SESSION_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pi/sessions"
```

Tracked source files therefore live under `~/dotfiles/pi/.config/pi/agent/` and
stow to `~/.config/pi/agent/`. Sessions are kept in
`~/.local/state/pi/sessions/` instead of the config directory.

Use no-folding because `~/.config/pi/agent` also contains runtime state such as
auth, package installs, generated extension config, package caches, and locally
installed skills/agents:

```bash
stow --restow --no-folding -v pi
```

## Installed Pi packages

`~/.config/pi/agent/settings.json` is tracked in this package so permanent
`pi install` entries are reproducible on a fresh machine. Runtime package
contents still live under `~/.config/pi/agent/npm/` and are not tracked.

Currently installed through settings:

- `npm:@juicesharp/rpiv-pi` — RPIV research/design/plan/implement/validate skills
- `npm:@juicesharp/rpiv-todo` — model-visible todo overlay/tool
- `npm:@juicesharp/rpiv-btw` — `/btw` side questions without polluting the main conversation
- `npm:@juicesharp/rpiv-workflow` — `/wf` workflow runner used by RPIV
- `npm:@juicesharp/rpiv-args` — `$ARGUMENTS` / `$1` expansion for RPIV skills
- `npm:@juicesharp/rpiv-i18n` — localization support used by RPIV packages
- `npm:@juicesharp/rpiv-ask-user-question` — structured clarification tool used by RPIV skills
- `npm:pi-mcp-adapter` — MCP bridge used by the Pi setup
- `npm:@juicesharp/rpiv-web-tools` — RPIV web/search tooling
- `npm:@that-yolanda/pi-context` — extra Pi context utilities
- `npm:pi-rewind` — session/history rewind utilities
- `npm:@tintinweb/pi-subagents` — Claude-Code-style subagent tooling package
- `npm:@juicesharp/rpiv-advisor` — RPIV advisor package

The earlier local workflow prototype is parked at
`~/.config/pi/agent/extensions-disabled/workflow/index.ts` so it does not collide
with RPIV commands/tools. Move it back under `extensions/` only if you want the
local prototype instead of RPIV.

## Local runtime experiments

See [`PI_RUNTIME_SCROLLBACK_FILE_MAP.md`](./PI_RUNTIME_SCROLLBACK_FILE_MAP.md)
for the current map of direct Pi runtime edits under `/opt/homebrew` and
`~/.config/pi/agent/npm`, including the internal scrollback patch, `/btw` overlay
scroll fix, backups, and reproduction commands for another agent.

## Starshipline

`~/.config/pi/agent/extensions/starshipline/index.ts` installs a Pi extension that:

- renders a clean left footer using colors/symbols from `~/.config/starship.toml`;
- can fall back to the raw `starship prompt` output with `/starshipline left starship`;
- shows richer git info: branch, staged/modified/untracked counts, stash, ahead/behind;
- adds Pi-side stats on the right: token totals, cache efficiency, cache read/write,
  cost, context pressure meter, model, and thinking level;
- provides `/starshipline` for live theme preset and color changes;
- has built-in Starshipline presets such as `starship-nord` (no separate Pi theme file is tracked).

Runtime config is written to `~/.config/pi/agent/starshipline.json` and is
intentionally not tracked.

Common commands:

```text
/starshipline                          open interactive menu
/starshipline left clean               clean path + git footer, no user@host or prompt symbol
/starshipline left starship            raw Starship prompt mode
/starshipline path-segments 8          set clean path truncation length
/starshipline theme from-starship      derive Pi theme colors from starship.toml
/starshipline theme starship-nord      use bundled Nord-like preset
/starshipline color accent #8fbcbb     override one Pi theme token live
/starshipline context-meter on         show context pressure bar
/starshipline cache-efficiency on      show prompt-cache efficiency
/starshipline prompt-char hide         hide trailing Starship prompt symbol in starship mode
/starshipline thinking on              show thinking level, e.g. gpt-5.5 · xhigh
/starshipline stats off                hide context/tokens/cache/cost
/starshipline refresh                  rerender the footer
```
