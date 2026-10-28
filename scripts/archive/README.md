# Archived scripts

Retired from active use but kept for reference (2026-08 bloat audit,
`docs/audit/2026-08-10-bloat-inventory.md`). Not stowed and not on `$PATH`
(see `scripts/.stow-local-ignore`).

- `fastrun-fire` / `fastrun-token` — EA Fastrun regression triggers
  (`fastrun.china.online.ea.com`); dead outside the EA network.
- `organize-class-files` — McGill-era course-file organizer.
- `open-dev-apps` / `open-dev-apps.sh` — WebStorm+Ghostty toggler (plain +
  Raycast script-command variants); WebStorm no longer installed. If Raycast
  still lists "Open Dev Apps", remove it there or repoint it here.
- `headroom-pi-copilot` — Headroom launcher that borrowed Pi's GitHub Copilot
  OAuth token (EA-era). The deployed launchd job now runs bare `headroom proxy`
  and Pi uses the ChatGPT subscription; see `HEADROOM_PI_COPILOT.md` (2026-09).
- `ipad/` — Sidecar/BetterDisplay controller (`ipad`), its USB auto-connect
  launch agent (`com.stanwang.ipad-attach.plist`), the `consume-launch-event`
  shim it ran through (`consume-launch-event.c`), and the Ctrl+Cmd+I Karabiner
  chord layer (`karabiner-ipad-layer.json`, one `rules[]` entry). Retired
  2026-10 in a battery audit; Sidecar is only used plugged in, via Control
  Center. To restore: move `ipad` back to `scripts/bin/`, rebuild the shim
  (`clang -O2 -o scripts/bin/consume-launch-event …/consume-launch-event.c`),
  re-add the plist and its `scripts/.stow-local-ignore` line, copy the plist
  into `~/Library/LaunchAgents/` as a real file, and splice the rule back in as
  the first `complex_modifications.rules` entry (it overrides h/l/d/r while
  held).
