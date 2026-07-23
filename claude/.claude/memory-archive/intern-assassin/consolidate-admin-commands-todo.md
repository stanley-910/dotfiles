---
name: consolidate-admin-commands-todo
description: Deferred plan to fold supervisor/admin slash commands under one /assassin-admin to cut Slack autocomplete bloat
metadata: 
  node_type: memory
  type: project
  originSessionId: d62a57c7-c069-4640-8232-e4521aaf9fb9
---

Deferred refactor for the Intern Assassin Slack bot: Slack has **no per-role slash-command
visibility**, so all ~13 commands show in everyone's `/` autocomplete. Plan is to collapse
the admin/supervisor levers behind a single `/assassin-admin <action>` command:

- Keep visible: `/assassin-signup`, `/assassin-start`, `/assassin-join`, `/assassin-leave`,
  `/assassin-status`, `/leaderboard`.
- Fold into `/assassin-admin`: `add`, `roster`, `master`, `undo`, `remove`, `advance`,
  `reset` (subcommand arg), reusing existing handler logic; bare/invalid action DMs the
  caller the actions *they're* allowed to use.

**Why:** the user finds ~13 commands bloated; this drops the visible surface to 7 and
hides the sensitive levers from the average player.

**How to apply:** route handlers through a dispatcher (keep the methods, change invocation),
update `slack-app-manifest.yml`, README command table, and tests. No scope change → no
reinstall, but needs manifest re-sync + `fly deploy`.

**Trigger:** the user wants to WAIT until the current signup period ends before changing
the command surface (avoid disrupting a live signup). Do not do it mid-signup.
