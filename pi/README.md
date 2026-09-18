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

`settings.json` pins Pi to the ChatGPT subscription through Pi's built-in
`openai-codex` provider (OAuth login via `pi auth`, stored in the untracked
`~/.config/pi/agent/auth.json`):

```json
{
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-6-astra",
  "enabledModels": ["openai-codex/*", "headroom/*"]
}
```

## Headroom provider

`models.json` adds one custom provider, `headroom`, so the same models can be
picked through the local Headroom proxy on `127.0.0.1:8787` (the service Claude
Code already uses). `openai-codex/gpt-6-astra` goes direct to chatgpt.com;
`headroom/gpt-6-astra` goes through the proxy:

```sh
pi --provider headroom --model gpt-6-astra
```

How it fits together:

- `api` is `openai-codex-responses`, Pi's ChatGPT transport. Pi appends
  `/codex/responses` to `baseUrl`, so `http://127.0.0.1:8787/backend-api`
  lands on Headroom's `/backend-api/codex/responses` route, which forwards to
  chatgpt.com using the request's own bearer token.
- `apiKey` is `!pi-codex-token` (`scripts/bin/`): it prints the `openai-codex`
  OAuth token from `auth.json`, refreshed via `pi auth print-bearer-token`.
  The script guards against recursion, because `pi auth` itself loads
  `models.json` and would otherwise re-run the command forever.
- Model metadata is copied from Pi's built-in catalog. To expose another
  ChatGPT model through the proxy, append it to the `models` array with the
  same `id` Pi uses for the direct provider.

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

- `npm:@juicesharp/rpiv-todo` — model-visible todo overlay/tool
- `npm:@juicesharp/rpiv-btw` — `/btw` side questions without polluting the main conversation
- `npm:@juicesharp/rpiv-i18n` — localization support used by RPIV packages
- `npm:@juicesharp/rpiv-ask-user-question` — structured clarification tool used by RPIV skills
- `npm:pi-mcp-adapter` — MCP bridge used by the Pi setup
- `npm:@juicesharp/rpiv-web-tools` — RPIV web/search tooling
- `npm:@that-yolanda/pi-context` — extra Pi context utilities
- `npm:pi-rewind` — session/history rewind utilities
- `npm:@tintinweb/pi-subagents` — Claude-Code-style subagent tooling package
- `npm:@juicesharp/rpiv-advisor` — RPIV advisor package

The RPIV workflow bundle (`rpiv-pi`, `rpiv-workflow`, and `rpiv-args`) is
uninstalled. Ordinary chat uses standalone tools and `pi-subagents`; the
bundle-generated agent definitions were archived outside Pi discovery.

## Optional MCP debugging

`context-mode` is disabled in normal sessions. Its tool-routing and memory
injection are reserved for explicit MCP-debugging sessions. Load it for one run:

```sh
pi -e npm:context-mode
```

Restart Pi after changing the package list; an existing session may still have
the extension loaded and previously injected context in its history.

## Tool prompt guidance

The following files are owned by this Stow package:

- `.config/pi/agent/subagents.json` selects the compact Agent tool description.
  Agent capabilities and parameter documentation are preserved. Project-local
  `.pi/subagents.json` settings override these global defaults.
- `.config/rpiv-todo/config.json` makes progress tracking situational instead of
  mandatory for every multi-step task.
- `.config/rpiv-ask-user-question/config.json` reserves structured choices for
  useful decisions; interview questions remain conversational.
- `.config/rpiv-web-tools/config.json` keeps source verification and inline links
  without requiring a separate Sources section in every response.

These use supported configuration overrides; installed package sources remain
untouched. Start a new Pi session after changing tool guidance.

Web search requires a search-provider credential. The default is Brave: set
`BRAVE_SEARCH_API_KEY` in the untracked `~/.secrets/env`, then launch Pi from a
fresh shell. Keep credentials there, not in the stowed web-tools config (the
`/web-tools` key-entry flow writes credentials to that config). `web_fetch` can
read ordinary pages without a search key.

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
