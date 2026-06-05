---
name: pi-package-discovery
description: Discover Pi packages that extend Pi with extensions, skills, prompts, or themes, then guide safe inspection before install. Use when the user asks to find Pi packages, extend Pi capabilities, search for extensions, or evaluate/install third-party Pi packages.
---

# Pi Package Discovery

Use this skill to find packages tagged `pi-package`, inspect their metadata, and gate installation behind an explicit user choice.

## Safety rules

- Never install a package during this skill without explicit user confirmation.
- Treat Pi packages as untrusted: extensions run local code; skills can instruct the model to run commands.
- Prefer trying a package ephemerally with `pi -e npm:<pkg>` before permanent `pi install npm:<pkg>`.
- Default audit mode is `ask` unless the user says `--audit always` or `--audit never`.

## Workflow

1. Parse the user's goal and audit preference:
   - `--audit ask` default: ask before auditing a candidate.
   - `--audit always`: inspect/audit candidates before recommending install.
   - `--audit never`: only show metadata; still ask before install.
2. Search npm packages:
   ```bash
   python3 /Users/stanwang/dotfiles/agents/.agents/skills/pi-package-discovery/scripts/search-npm-pi-packages.py "<query>" --limit 15
   ```
3. Pick the most relevant candidates and inspect metadata:
   ```bash
   python3 /Users/stanwang/dotfiles/agents/.agents/skills/pi-package-discovery/scripts/inspect-npm-pi-package.py <package-name>
   ```
4. Summarize:
   - What capability it appears to add.
   - Whether it contains extensions, skills, prompts, or themes.
   - Obvious risk flags: install scripts, many dependencies, missing repo, stale package, unclear manifest.
5. If audit is enabled or requested, stop and ask before deeper code audit. Suggested prompt:
   > I found `<pkg>`. Do you want a deeper audit before trying/installing it? Options: `metadata only`, `audit code`, `try once with pi -e`, `install permanently`.
6. If the user approves permanent install, run:
   ```bash
   pi install npm:<package-name>
   ```
   Then suggest `pi config` if they want to enable/disable resources.

## Current helper scope

This first version performs npm search and package metadata inspection. Deeper source-code audit can be done manually by unpacking the tarball into a temp directory and reviewing `package.json`, extension files, dependencies, and lifecycle scripts before installation.
