# Personal-Mac migration guide

One-time guide for adopting this repo on the personal Mac after the 2026
internship. Written 2026-08 against the state audited in
`docs/audit/2026-08-internship-dossier.md`; skim `CHANGELOG.md` first to see
what changed since you last lived in this repo.

Branch story: the internship machine's `mac` branch became the new `main`.
Your old personal lineage (frozen 2025-08-11, unrelated history) is archived
untouched as `main-legacy` — nothing was deleted.

## 1. Point the repo at the new main

Existing clone (still on the old lineage):

```bash
cd ~/dotfiles
git stash -u          # or commit — don't lose local edits
git fetch origin
git checkout -B main origin/main   # replaces local main with the new lineage
```

Fresh machine: clone normally — `git clone git@github.com:stanley-910/dotfiles.git ~/dotfiles`.

Old files worth comparing live at `origin/main-legacy` (`git diff main-legacy -- <path>`).

## 2. Secrets

Create `~/.secrets/env` (sourced by `.zshenv`, never tracked) and put API
keys/tokens there before opening new shells.

## 3. Install

Fresh Mac: run `./prepper.sh` first (Homebrew, GUI casks, macOS defaults,
Mos seeding, SSH, Helium default-browser) — then `./bootstrap.sh` (stow
packages, XDG state dirs, shared-skill consumer links via `install-skill`).

Existing Mac: skip prepper (or cherry-pick its `step_*` functions) and run
`./bootstrap.sh`; it simulates stow and asks before linking, and backs up
real files that collide. Then:

```bash
brew bundle install                              # core
brew bundle install --file=Brewfile.external     # daily drivers — review first
```

Stow modes (full vs `--no-folding`) are documented in `CLAUDE.md`; bootstrap
already applies the right mode per package.

## 4. Work-only pieces — keep dormant, don't install

Everything work-flavored stays in the repo but is inert without EA
network/auth. Deliberate decisions, not oversights (see the dossier):

- **Headroom proxy stack** (`scripts/bin/headroom-pi-copilot`,
  `scripts/Library/LaunchAgents/com.stanwang.headroom-proxy.plist`,
  `scripts/HEADROOM_PI_COPILOT.md`): do **not** deploy the launchd plist.
  Without the proxy, `127.0.0.1:8787` is just a closed port.
- **Pi default provider**: `pi/.config/pi/agent/settings.json` defaults to
  `headroom-copilot/gpt-5.6-sol`, which needs the proxy. Change
  `defaultProvider`/`defaultModel` to a provider you have auth for (e.g.
  `github-copilot/...` with a personal Copilot, or an Anthropic key). The
  `apiKey: "headroom-local"` in `models.json` is a proxy sentinel, not a
  credential — leave it.
- **`hpi` launcher** (`zsh/.zshrc`) and the Copilot-fleet delegation docs
  (`claude/.claude/CLAUDE.md`, `DELEGATION.md`): leave unchanged. The docs
  carry an explicit "if pi or Copilot auth is unavailable, run natively"
  guard, so they're dormant by design.
- **EA helpers** (`scripts/bin/fastrun-*`, gitlab.ea.com/Jenkins/Jira
  matchers in `open_remote.sh`): kept intentionally; they only activate on
  EA hosts/remotes and are no-ops elsewhere.

## 5. Machine-specific touches

- **Starship**: add the new Mac's hostname to the alias map in
  `starship/.config/starship.toml` (aliases render as `m4p`) — check with
  `scutil --get LocalHostName`.
- **Optional backup restores** (each documented in its package README):
  Raycast `raycast/*.rayconfig` (Settings → Import), IntelliJ/WebStorm
  `jetbrains/.config/jetbrains/*/settings.zip` (File → Manage IDE Settings →
  Import), Cursor `cursor/.config/cursor/macos.code-profile` (profile
  import). Stale `/Users/stanley` paths inside them are harmless.

## 6. Post-checks

- New shell opens clean; `echo $PATH` includes `~/dotfiles/scripts/bin`.
- `tmux` then `prefix + I` to install plugins; grant Karabiner permissions
  (Accessibility + Input Monitoring); `nvim` boots and Mason installs LSPs.
- Skills intact: `agents/.agents/skills/install-skill/scripts/verify-skill <name>`
  for a couple of skills (or re-run bootstrap's skill step).
- Drift baseline: `python3 agents/.agents/skills/dotfiles-drift/scripts/audit_dotfiles_drift.py --repo .`
  — first run on a new machine just seeds its local snapshot; findings
  against `Brewfile*`/`prepper.sh` are your real to-install list.
- When settled: delete the leftover `mac` branch
  (`git push origin :mac; git branch -d mac`) — it's a synonym of `main`
  kept only for this transition.
