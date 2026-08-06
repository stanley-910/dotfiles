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

## Default model

`settings.json` pins Pi to the Headroom/Copilot `gpt-5.6-sol` model with the
`high` thinking level. This uses the local Headroom proxy defined in
`models.json`, not Pi's built-in `github-copilot` provider:

```json
{
  "defaultProvider": "headroom-copilot",
  "defaultModel": "gpt-5.6-sol",
  "defaultThinkingLevel": "high"
}
```

The `apiKey: "headroom-local"` in `.config/pi/agent/models.json` is a sentinel that the local Headroom proxy ignores, not a credential; do not move it to `~/.secrets/env`.

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

The earlier local workflow prototype has been removed; `@juicesharp/rpiv-workflow`
provides the active workflow commands.

## Agent worktree convention

Global Pi agent instructions live at
`pi/.config/pi/agent/AGENTS.md` and stow to `~/.config/pi/agent/AGENTS.md`.
They mirror the Claude-agent worktree taxonomy:

```text
~/worktrees/<project-name>/<YYYY-MM-DD_slug>/integration
~/worktrees/<project-name>/<YYYY-MM-DD_slug>/<slice-id>
```

Use branch names like `orchestrate/<YYYY-MM-DD_slug>/<slice-id>` for multi-slice
runs, and repo-conventional prefixes such as `fix/`, `feat/`, or `chore/` for
single-ticket work. Keep worktrees persistent until Stanley asks for cleanup.

## Starshipline

`~/.config/pi/agent/extensions/starshipline/index.ts` installs a Pi extension that:

- renders a clean path and detailed Git state using colors/symbols from
  `~/.config/starship.toml`;
- keeps path/Git and model/thinking compact on the left, while right-aligning
  extension statuses and context with two-space separators;
- shows context pressure as percent, a ten-cell bar, and compact current/limit
  tokens;
- includes only actionable extension statuses: Pi Talk play/pause state and speed,
  RPIV workflow stage, and active/queued subagent counts;
- keeps token totals, cache telemetry, cost, MCP health, rewind checkpoints, and
  generic RPIV skill labels hidden by default;
- can fall back to raw `starship prompt` output with `/starshipline left starship`;
- provides `/starshipline` for live theme preset and color changes;
- has built-in Starshipline presets such as `starship-nord` (no separate Pi theme
  file is tracked).

Runtime config is written to `~/.config/pi/agent/starshipline.json` and is
intentionally not tracked. Common commands:

```text
/starshipline                          open interactive menu
/starshipline left clean               clean path + Git footer
/starshipline left starship            raw Starship prompt mode
/starshipline path-segments 5          set clean path truncation length
/starshipline theme from-starship      derive Pi theme colors from starship.toml
/starshipline theme starship-nord      use bundled Nord-like preset
/starshipline color accent #8fbcbb     override one Pi theme token live
/starshipline context-meter on         show context percent, bar, and token usage
/starshipline cache-efficiency on      opt into prompt-cache efficiency
/starshipline prompt-char hide         hide trailing Starship prompt symbol in starship mode
/starshipline thinking on              show thinking level, e.g. gpt-5.6-sol · high
/starshipline stats off                hide context and optional telemetry
/starshipline refresh                  rerender the footer
```
