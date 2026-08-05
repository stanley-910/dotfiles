---
name: install-skill
description: Install and verify owned skills across the dotfiles source, stowed shared hub, Claude, and Pi consumer locations. Use whenever an agent adds, installs, updates, stows, repairs, or checks the integrity of a skill in this dotfiles repository.
---

# Install skill

Use the bundled scripts instead of manually running Stow or creating consumer links.

## Choose the scope

- Use `shared` for agent-agnostic skills. This is the default.
- Use `claude` only when the skill depends on Claude-specific mechanics such as the Agent tool, subagents, or Explore.
- Never replace `~/.claude/skills` with one directory symlink. It contains both shared child symlinks and stowed Claude-only skills.

## Install

Create or update the canonical skill source first, then run:

```bash
# Shared skill
scripts/install-skill <name>

# Claude-only skill
scripts/install-skill --scope claude <name>
```

The installer validates the skill name, runs GNU Stow, creates the required shared-skill consumer links, and calls the verifier.

If a wrong file, directory, or symlink blocks a consumer location, stop and ask before using `--force`. That flag removes the blocking path.

## Verify integrity

```bash
# Shared skill
scripts/verify-skill <name>

# Claude-only skill
scripts/verify-skill --scope claude <name>
```

The verifier is read-only. It reports every required location as `OK`, `MISSING`, or `INVALID` and exits nonzero unless all locations resolve to the canonical source.

## Managed locations

Shared skills:

1. `~/dotfiles/agents/.agents/skills/<name>`: canonical source
2. `~/.agents/skills/<name>`: GNU Stow hub
3. `~/.claude/skills/<name>`: child symlink to the hub
4. `~/.config/pi/agent/skills/<name>`: child symlink to the hub

Claude-only skills:

1. `~/dotfiles/claude/.claude/skills/<name>`: canonical source
2. `~/.claude/skills/<name>`: GNU Stow target
