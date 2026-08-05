# tldraw offline agent skill

The version-controlled source of truth is:

```text
~/dotfiles/agents/.agents/skills/tldraw-offline/
```

GNU Stow exposes it at `~/.agents/skills/tldraw-offline`, which Pi reads directly. Claude, Cursor, Codex, Gemini, and the legacy `~/skills/tldraw-offline` location point back to that shared hub. Do not use tldraw Desktop's **Install agent skills** action on this machine; it creates separate managed copies and can replace the shared symlinks on a later app upgrade.

Files:

- `SKILL.md` — shared workflow and API guidance
- `tq` — authenticated canvas API helper
- `tq-sync` — stage and apply a multi-file document script within one watcher debounce window
- `inject-server-context.sh` — Claude/Codex hook payload
- `harnesses/` — tracked vendor-specific agent wrappers

All runtime paths derive from `$HOME`. Override server discovery for tests with `TLDRAW_SERVER_JSON=/path/to/server.json`.
