# Pi

Pi Coding Agent config managed by GNU Stow.

Use no-folding because `~/.pi/agent` also contains runtime state such as sessions,
auth, package installs, generated extension config, and npm package caches:

```bash
stow --restow --no-folding -v pi
```

## Installed Pi packages

`~/.pi/agent/settings.json` is tracked in this package so permanent `pi install`
entries are reproducible on a fresh machine. Runtime package contents still live
under `~/.pi/agent/npm/` and are not tracked.

Currently installed through settings:

- `npm:pi-subagents` — existing local subagent package/skill used by this dotfiles setup
- `npm:@tintinweb/pi-subagents` — RPIV-compatible Claude-Code-style `Agent` subagent tools
- `npm:@juicesharp/rpiv-pi` — RPIV research/design/plan/implement/validate skills
- `npm:@juicesharp/rpiv-workflow` — `/wf` workflow runner used by RPIV
- `npm:@juicesharp/rpiv-args` — `$ARGUMENTS` / `$1` expansion for RPIV skills
- `npm:@juicesharp/rpiv-i18n` — localization support used by RPIV packages
- `npm:@juicesharp/rpiv-ask-user-question` — structured clarification tool used by RPIV skills
- `npm:@juicesharp/rpiv-todo` — model-visible todo overlay/tool
- `npm:@juicesharp/rpiv-btw` — `/btw` side questions without polluting the main conversation

The earlier local workflow prototype is parked at
`~/.pi/agent/extensions-disabled/workflow/index.ts` so it does not collide with
RPIV commands/tools. Move it back under `extensions/` only if you want the local
prototype instead of RPIV.

## Starshipline

`~/.pi/agent/extensions/starshipline/index.ts` installs a Pi extension that:

- renders a clean left footer using colors/symbols from `~/.config/starship.toml`;
- can fall back to the raw `starship prompt` output with `/starshipline left starship`;
- shows richer git info: branch, staged/modified/untracked counts, stash, ahead/behind;
- adds Pi-side stats on the right: token totals, cache efficiency, cache read/write,
  cost, context pressure meter, model, and thinking level;
- provides `/starshipline` for live theme preset and color changes;
- includes the static `starship-nord` Pi theme for use from `/settings`.

Runtime config is written to `~/.pi/agent/starshipline.json` and is intentionally
not tracked.

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
