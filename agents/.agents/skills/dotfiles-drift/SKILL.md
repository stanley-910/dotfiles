---
name: dotfiles-drift
description: Audit macOS dotfiles/bootstrap drift by comparing the current machine against Prepper/bootstrap scripts, Brewfile declarations, and the previous local snapshot, then produce reports and patch suggestions. Use when the user mentions dotfiles drift, Prepper drift, bootstrap drift, fresh-Mac scripts, Brewfile drift, installed app/package drift, or macOS defaults drift.
---

# Dotfiles Drift

## Goal

Help keep the dotfiles bootstrap path honest. The audit is read-only against the machine and writes only a local snapshot/report. It compares:

- current Homebrew formulae/casks against `Brewfile*` and `prepper.sh` casks
- `/Applications` and `~/Applications` app bundles against prior snapshots and installed casks
- global language-manager tools against the previous snapshot
- macOS preferences via the `defaults` CLI against `prepper.sh` declarations plus known preference domains

## Quick start

From the dotfiles repo:

```bash
python3 agents/.agents/skills/dotfiles-drift/scripts/audit_dotfiles_drift.py --repo .
```

The script prints the report path and stores both reports and private snapshots under `~/.local/state/dotfiles-drift/`.

## Workflow for agents

1. Confirm repo context first:
   ```bash
   git status --short
   test -f prepper.sh && test -f bootstrap.sh && ls Brewfile*
   ```
2. Run the audit script. Do not mutate `prepper.sh`, `bootstrap.sh`, or `Brewfile*` during the audit.
3. Read the generated Markdown report, focusing on:
   - `Extra installed Homebrew leaves`
   - `Extra installed casks`
   - `Possible non-Homebrew apps`
   - `Language tool changes since previous snapshot`
   - `Declared defaults mismatches`
   - `Known defaults domain changes since previous snapshot`
4. Treat patch snippets as recommendations, not commands. Ask the user which candidates are intentional before editing.
5. If edits are approved, update the dotfiles source files only:
   - required CLI tools → `Brewfile`
   - optional/personal CLI tools → `Brewfile.external` when present
   - fresh-Mac GUI apps → `prepper.sh` `step_casks` array
   - macOS preference changes → `prepper.sh` `step_macos_defaults` or app-specific step
6. Re-run the audit after edits. The second report should show fewer repo-vs-machine drifts while snapshot-vs-snapshot changes become the new baseline.

## Defaults audit rules

- Prefer the helper script's `defaults read`/`defaults export` evidence over guessing from System Settings labels.
- Simple `defaults write DOMAIN KEY -bool/-int/-float/-string/-data VALUE` lines are comparable to live values.
- `-dict-add`, loop-generated keys, and packed blobs can be collected but often need manual review.
- Known-domain changes are intentionally coarse: they show which preference domains/keys changed since the previous snapshot, not every value inline.
- Do not run `defaults write`, `defaults delete`, `killall cfprefsd`, or app restarts unless the user explicitly approves remediation.

## Report interpretation

- `Missing declared` means the scripts declare something that is not installed now. Either install it or remove stale declarations.
- `Extra installed` means this machine has something the scripts do not declare. Ask whether it belongs in bootstrap or should stay machine-local.
- First run has no previous snapshot; it establishes the baseline for future drift audits.
- Language-manager tools usually have no existing bootstrap destination. Recommend a new explicit section only if the user wants those tools reproduced on fresh machines.
