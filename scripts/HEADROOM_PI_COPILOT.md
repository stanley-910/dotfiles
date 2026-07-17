# Headroom with Pi GitHub Copilot

## Purpose

This guide reproduces and operates the persistent local Headroom proxy used by
Pi in this checkout.

The intended split is:

- `pi` remains the normal, direct `github-copilot/gpt-5.6-sol` path.
- `hpi` opts into `headroom-copilot/gpt-5.6-sol` through Headroom on
  `127.0.0.1:8787`.
- GPT and Gemini aliases use Headroom.
- Copilot Claude models remain direct and are included in `hpi`'s model picker
  only for convenient switching.

This avoids starting a proxy or logging Headroom into GitHub for every chat.
Headroom is a persistent launchd service and reuses Pi's stored Copilot OAuth
credential.

### Non-goals

This setup does **not**:

- Replace the built-in `github-copilot` provider globally.
- Route Copilot Claude models through Headroom.
- Dynamically mirror every model added to Pi's catalog.
- Bypass GitHub Copilot quotas or entitlement checks.
- Route every delegated subagent through Headroom.
- Register Headroom's `headroom_retrieve` tool in Pi.
- Eliminate every future GitHub login; a revoked or replaced refresh credential
  still requires a real Pi re-login.

## Configuration invariant

The opt-in design keeps these values in
[`../pi/.config/pi/agent/settings.json`](../pi/.config/pi/agent/settings.json):

```json
{
  "defaultProvider": "github-copilot",
  "defaultModel": "gpt-5.6-sol"
}
```

Pi normally persists every interactive `/model` selection as the global
default. To prevent a model switch inside `hpi` from changing what a later bare
`pi` uses, `hpi` starts Pi with an ephemeral agent directory:

- `settings.json` and `auth.json` are copied into a mode-0700 temporary
  directory; the copies are mode 0600.
- The remaining Pi resources are symlinked from the normal agent directory.
- `PI_CODING_AGENT_SESSION_DIR` is inherited, so normal session storage remains
  available.
- The temporary directory is removed when Pi exits normally.

This isolates settings writes made by `/model`. It also means `/login`, package
settings, or other persistent configuration changes made inside `hpi` are
written to the temporary copy and discarded. Perform configuration and login
changes from regular `pi` instead. Existing saved sessions may retain their
previously selected model.

Verify the regular default without printing credentials:

```sh
python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / "dotfiles/pi/.config/pi/agent/settings.json"
data = json.loads(path.read_text())
assert data["defaultProvider"] == "github-copilot"
assert data["defaultModel"] == "gpt-5.6-sol"
print("bare pi default: github-copilot/gpt-5.6-sol")
PY
```

## Architecture and data flow

### Headroom GPT/Gemini path

```text
hpi
  -> Pi selects headroom-copilot/<model>
  -> Pi sends an OpenAI Responses or Chat Completions request
     to http://127.0.0.1:8787/v1
  -> Headroom performs lossless request compression
  -> Headroom exchanges Pi's reusable Copilot refresh credential for a
     short-lived Copilot API token
  -> Headroom forwards to the resolved GitHub Copilot API endpoint
  -> the response streams back through Headroom to Pi
```

### Direct paths

```text
pi
  -> github-copilot/gpt-5.6-sol
  -> Pi's built-in GitHub Copilot OAuth and endpoint handling
  -> GitHub Copilot

hpi, after selecting github-copilot/claude-*
  -> Pi's anthropic-messages implementation
  -> Pi's built-in Copilot Bearer authentication
  -> GitHub Copilot
```

The separate `headroom-copilot` provider is deliberate. Pi resolves stored auth
before a configured provider key, and its GitHub Copilot OAuth provider can
rewrite the model base URL to the account-specific Copilot endpoint. Reusing the
literal `github-copilot` provider name would therefore let Pi's OAuth handling
supersede the local dummy key and proxy URL. The separate provider has no stored
OAuth entry, so its dummy local key satisfies Pi's availability check while
Headroom owns upstream authentication. See Pi's official
[custom-model documentation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md)
and the installed implementation references at the end of this guide.

## Files

| File | Role |
| --- | --- |
| [`bin/headroom-pi-copilot`](bin/headroom-pi-copilot) | Reads Pi's stored Copilot credential, resolves the upstream, exports Headroom auth/routing variables, and starts `headroom proxy`. |
| [`Library/LaunchAgents/com.stanwang.headroom-proxy.plist`](Library/LaunchAgents/com.stanwang.headroom-proxy.plist) | Versioned launchd job source. Runs the helper persistently on port 8787. |
| [`.stow-local-ignore`](.stow-local-ignore) | Excludes the plist because its deployed target must be a real file, not a Stow symlink. |
| [`../pi/.config/pi/agent/models.json`](../pi/.config/pi/agent/models.json) | Defines the separate `headroom-copilot` provider and its 11 manually mirrored aliases. |
| [`../pi/.config/pi/agent/settings.json`](../pi/.config/pi/agent/settings.json) | Holds the bare `pi` default. It should remain direct `github-copilot/gpt-5.6-sol`. |
| [`../zsh/.zshrc`](../zsh/.zshrc) | Defines the opt-in `hpi` function and its scoped model picker. |
| `~/.config/pi/agent/auth.json` | Pi-owned credential store read by the helper. Never copy its contents into this repo or logs. |
| `~/Library/LaunchAgents/com.stanwang.headroom-proxy.plist` | Deployed real-file copy loaded by launchd. |
| `~/.headroom/logs/launchd.out.log` | Service stdout. |
| `~/.headroom/logs/launchd.err.log` | Service stderr. |

The tracked plist currently contains absolute paths for
`/Users/stanwang/dotfiles` and `/Users/stanwang`. If this checkout or account is
moved, update the tracked plist before deploying it.

## Prerequisites

- macOS with per-user launchd agents.
- Pi installed and available as `pi`.
- A GitHub Copilot account entitled to the selected models.
- One successful direct Pi GitHub Copilot login, producing a
  `github-copilot` entry in `~/.config/pi/agent/auth.json`.
- Python 3 for the credential-parsing helper.
- `uv` for the exact installation command below, or another supported Python
  tool installer.
- GNU Stow for deploying the Pi and zsh packages.
- Headroom with proxy support installed and available as `headroom`.
- `$HOME/dotfiles/scripts/bin` on `PATH`, as configured by this dotfiles repo.

Versions validated for this guide:

```text
Pi       0.80.7
Headroom 0.30.0
```

Headroom 0.30.0 is the installed version, not a claim about the latest release.
The package's official source is the
[Headroom repository](https://github.com/chopratejas/headroom), and Pi's source
is the [earendil-works Pi repository](https://github.com/earendil-works/pi).

## First-time installation and deployment

### 1. Install the validated Headroom version

This machine uses a uv-managed tool installation:

```sh
uv tool install "headroom-ai[proxy]==0.30.0"
headroom --version
```

If Headroom is already installed, do not reinstall it solely to follow this
guide. Confirm its version and flags first:

```sh
headroom --version
headroom proxy --help | grep -E -- '--no-rate-limit|--lossless|--no-subscription-tracking'
```

Headroom's official installation options are documented in its
[installation guide](https://headroom-docs.vercel.app/docs/installation).

### 2. Install the Pi and zsh dotfiles

From the repo root:

```sh
cd "$HOME/dotfiles"
stow --restow --no-folding pi
stow --restow zsh
```

`scripts/bin` is intentionally on `PATH` directly; the helper does not need a
Stow symlink.

### 3. Establish Pi's direct Copilot login

Start Pi normally, then use `/login` and choose GitHub Copilot:

```sh
pi
```

Do not print `auth.json`. Check only the required structure:

```sh
python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / ".config/pi/agent/auth.json"
data = json.loads(path.read_text())
credential = data.get("github-copilot")
assert isinstance(credential, dict), "missing github-copilot login"
assert credential.get("access"), "missing Copilot access field"
assert credential.get("refresh"), "missing Copilot refresh field"
print("Pi Copilot credential: present with access and refresh fields")
PY
```

The helper defaults to refresh mode. Static mode exists for diagnosis but uses
the current short-lived access token and expires sooner:

```sh
headroom-pi-copilot --dry-run
headroom-pi-copilot --static-token --dry-run
```

Dry-run output contains the auth mode, upstream host, and listen address, but
must never print the credential itself.

### 4. Ensure bare `pi` remains direct

Apply or verify the configuration invariant described above. A new bare `pi`
session should select:

```text
github-copilot/gpt-5.6-sol
```

This step is what keeps regular Pi independent of the Headroom service.

### 5. Deploy the launchd plist as a real file

`launchctl` rejected this plist when Stow deployed it as a symlink. The source
is therefore excluded in [`.stow-local-ignore`](.stow-local-ignore) and copied
with `install`.

```sh
label=com.stanwang.headroom-proxy
source_plist="$HOME/dotfiles/scripts/Library/LaunchAgents/$label.plist"
target_plist="$HOME/Library/LaunchAgents/$label.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.headroom/logs"
plutil -lint "$source_plist"
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
install -m 644 "$source_plist" "$target_plist"
test -f "$target_plist" && test ! -L "$target_plist"
launchctl bootstrap "gui/$UID" "$target_plist"
launchctl enable "gui/$UID/$label"
launchctl kickstart -k "gui/$UID/$label"
```

The job uses `RunAtLoad` and `KeepAlive`. Its effective command is:

```text
headroom-pi-copilot --refresh --port 8787 -- --no-rate-limit --lossless
```

The helper also adds `--no-subscription-tracking`.

- `--no-rate-limit` disables Headroom's local limiter. GitHub's own quota and
  throttling still apply.
- `--lossless` enables Headroom's no-CCR, format-aware lossless compression. In
  installed 0.30.0 it also disables CCR markers and `headroom_retrieve` tool
  injection. This matters because this Pi setup does not register that retrieval
  tool; an injected tool definition could otherwise lead the model to request a
  tool Pi cannot execute. See Headroom's tagged
  [`--lossless` implementation](https://github.com/chopratejas/headroom/blob/v0.30.0/headroom/cli/proxy.py).

### 6. Reload zsh

The function in [`../zsh/.zshrc`](../zsh/.zshrc) stages the isolated Pi config
described above, then launches:

```zsh
PI_CODING_AGENT_DIR="$runtime_dir" command pi \
  --model headroom-copilot/gpt-5.6-sol \
  --models "headroom-copilot/*,github-copilot/claude-*" \
  "$@"
```

Read the tracked function for the complete staging and cleanup logic. Open a
new shell or reload the existing one after changing it:

```sh
source "$HOME/.zshrc"
```

`"$@"` forwards every user flag unchanged. Pi accepts a later user-supplied
`--model` or `--models` value, so `hpi --model ...` selects a different initial
model without changing regular Pi's saved default.

## Normal use

Use direct Pi as before:

```sh
pi
```

Use Headroom:

```sh
hpi
hpi --thinking high
hpi --no-session -p "Summarize this repository"
hpi --tools read,grep,find,ls
```

The Headroom service is shared across chats. Do not start a second proxy on port
8787 for each Pi session.

If Headroom is unavailable, `hpi` fails rather than automatically falling back
to direct Copilot. Use bare `pi` or an explicit direct model while repairing the
service:

```sh
pi --model github-copilot/gpt-5.6-sol
```

## Selecting models

Inside `hpi`, open `/model` or use Pi's model-selector keybinding. The scoped
view contains:

```text
headroom-copilot/*
github-copilot/claude-*
```

If an older session shows only the normal global scope, switch the picker from
`scoped` to `all`, or start a new session through the current `hpi` function.

Select a Headroom alias at launch:

```sh
hpi --model headroom-copilot/gpt-5.4
hpi --model headroom-copilot/gemini-3.1-pro-preview
```

Select a direct Claude model at launch:

```sh
hpi --model github-copilot/claude-sonnet-5
```

That Claude command uses `hpi`'s picker convenience but bypasses Headroom.

List configured aliases without making a model request:

```sh
pi --list-models headroom-copilot
pi --list-models github-copilot
```

Account policy and Pi's stored Copilot availability metadata can hide built-in
models even when they exist in Pi's generated catalog.

## Model and protocol matrix

The aliases are manually defined in
[`../pi/.config/pi/agent/models.json`](../pi/.config/pi/agent/models.json). Pi
supports provider- and model-level API types as documented in its official
[custom-model reference](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md).

| Models | Pi wire API | Route | Status |
| --- | --- | --- | --- |
| `gemini-2.5-pro` | `openai-completions` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gemini-3-flash-preview` | `openai-completions` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gemini-3.1-pro-preview` | `openai-completions` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5-mini` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.3-codex` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.4` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.4-mini` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.5` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.6-luna` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| `gpt-5.6-sol` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored; `hpi` initial model |
| `gpt-5.6-terra` | `openai-responses` | `headroom-copilot` -> Headroom -> Copilot | Mirrored |
| Available `github-copilot/claude-*` | `anthropic-messages` | Pi -> Copilot directly | Visible in `hpi`; not proxied |

### Why Claude remains direct

Pi's built-in Copilot Claude path is provider-specific:

- The models use `anthropic-messages`.
- Pi recognizes the literal `github-copilot` provider and configures the
  Anthropic client with Copilot's token as Bearer auth.
- Pi adds Copilot-specific headers and compatibility behavior.

A naive `headroom-copilot/claude-*` alias would no longer trigger Pi's literal
`github-copilot` special case. It would send the dummy local key using ordinary
Anthropic provider behavior, and this helper does not configure a tested
Copilot Anthropic target. Merely adding aliases would therefore risk sending
the request to the wrong upstream or with the wrong authentication. The
installed Pi implementation is
`/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/api/anthropic-messages.js`.

Do not add Claude aliases until streaming, tools, images, thinking, upstream
routing, and Copilot Bearer auth are implemented and tested end to end.

## launchd operations

Set reusable shell variables:

```sh
label=com.stanwang.headroom-proxy
plist="$HOME/Library/LaunchAgents/$label.plist"
```

Inspect status:

```sh
launchctl print "gui/$UID/$label"
```

Restart after a Pi re-login, helper change, or Headroom upgrade:

```sh
launchctl kickstart -k "gui/$UID/$label"
```

Stop and unload:

```sh
launchctl bootout "gui/$UID/$label"
```

Load an existing deployed plist:

```sh
launchctl bootstrap "gui/$UID" "$plist"
launchctl enable "gui/$UID/$label"
```

Redeploy after changing the tracked plist:

```sh
label=com.stanwang.headroom-proxy
source_plist="$HOME/dotfiles/scripts/Library/LaunchAgents/$label.plist"
target_plist="$HOME/Library/LaunchAgents/$label.plist"

plutil -lint "$source_plist"
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
install -m 644 "$source_plist" "$target_plist"
launchctl bootstrap "gui/$UID" "$target_plist"
launchctl enable "gui/$UID/$label"
```

Follow logs:

```sh
tail -f "$HOME/.headroom/logs/launchd.out.log" \
        "$HOME/.headroom/logs/launchd.err.log"
```

## Health checks and smoke tests

### Process and file checks

```sh
label=com.stanwang.headroom-proxy
source_plist="$HOME/dotfiles/scripts/Library/LaunchAgents/$label.plist"
target_plist="$HOME/Library/LaunchAgents/$label.plist"

plutil -lint "$source_plist"
cmp "$source_plist" "$target_plist"
test -f "$target_plist" && test ! -L "$target_plist"
launchctl print "gui/$UID/$label" | grep -E 'state =|pid =|last exit code'
```

### HTTP health

```sh
curl -fsS "http://127.0.0.1:8787/livez"
curl -fsS "http://127.0.0.1:8787/readyz"
curl -fsS "http://127.0.0.1:8787/stats"
```

Assert that readiness is healthy and Headroom's local limiter is disabled:

```sh
curl -fsS "http://127.0.0.1:8787/readyz" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["ready"] is True
assert r["checks"]["rate_limiter"]["enabled"] is False
print("Headroom ready; local rate limiter disabled")
'
```

### Headroom model smoke test

After loading the zsh function:

```sh
source "$HOME/.zshrc"
hpi --no-session -p "Reply with exactly HEADROOM_OK"
```

Or bypass the shell function:

```sh
pi --model headroom-copilot/gpt-5.6-sol \
  --no-session -p "Reply with exactly HEADROOM_OK"
```

Check the service logs or `/stats` immediately afterward to confirm that
Headroom handled the request. A successful model response alone does not prove
the configured route if the provider name was changed.

### Optional direct-path comparison

```sh
pi --model github-copilot/gpt-5.6-sol \
  --no-session -p "Reply with exactly DIRECT_OK"
```

This intentionally exercises Pi's direct OAuth path and may refresh its stored
credential. It is not required when testing only Headroom alias changes.

## Authentication lifecycle

[`bin/headroom-pi-copilot`](bin/headroom-pi-copilot) performs the following at
each service start:

1. Reads only the `github-copilot` entry from
   `~/.config/pi/agent/auth.json`.
2. Extracts access and refresh fields without printing them.
3. Derives the Copilot API host from the structured access credential's
   `proxy-ep` value unless `HEADROOM_COPILOT_UPSTREAM` overrides it.
4. Normalizes a `proxy.*` Copilot host to the corresponding `api.*` host.
5. Exports `GITHUB_COPILOT_API_URL` and `OPENAI_TARGET_API_URL`.
6. In default refresh mode, exports the reusable credential through
   `GITHUB_COPILOT_GITHUB_TOKEN` and enables
   `GITHUB_COPILOT_USE_TOKEN_EXCHANGE`.
7. Executes Headroom, which exchanges and caches a short-lived Copilot API
   token.

The launchd plist contains no GitHub secret. The credential enters Headroom's
process environment at runtime and is not passed as a command-line argument.

Headroom reads Pi's stored credential when the service starts, not every time
`hpi` starts. After `/login`, logout/login, account switching, or any Pi action
that replaces the stored Copilot credential, restart Headroom so it rereads
`auth.json`:

```sh
launchctl kickstart -k "gui/$UID/com.stanwang.headroom-proxy"
```

If GitHub revokes the reusable credential, log in once through direct Pi and
then restart the service. Repeatedly restarting Headroom cannot repair a
revoked refresh credential.

## macOS Keychain password prompt

Installed Headroom 0.30.0 eagerly builds a complete Copilot token candidate
list whenever it resolves a reusable credential, including after its cached
short-lived API token expires. Even when `GITHUB_COPILOT_GITHUB_TOKEN` already
supplies the explicit Pi refresh credential, discovery continues into the macOS
Keychain fallback. That fallback runs `security find-generic-password ... -w`
and `security find-internet-password ... -w`, which can trigger a macOS password
or Keychain-access dialog after Headroom has been idle.

Primary implementation references for the installed version:

- `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/copilot_auth.py`
  (`iter_oauth_token_candidates` appends the environment candidate and then
  invokes the Keychain reader).
- `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/copilot_macos_keychain.py`
  (constructs and executes the `security` commands).
- Official tagged source:
  [`copilot_auth.py`](https://github.com/chopratejas/headroom/blob/v0.30.0/headroom/copilot_auth.py)
  and
  [`copilot_macos_keychain.py`](https://github.com/chopratejas/headroom/blob/v0.30.0/headroom/copilot_macos_keychain.py).

Keep these behaviors separate:

- Starting `hpi` does **not** call Keychain. The function stages local config
  copies and invokes Pi; it does not restart Headroom or run `security`.
- Starting or restarting Headroom, or making the first request after its cached
  API token expires, can trigger credential discovery.

The tracked LaunchAgent sets `GITHUB_COPILOT_KEYCHAIN_SERVICE` to the nonexistent
sentinel service `__headroom_explicit_token_only__`. In Headroom 0.30.0 this
replaces the default generic-password service candidates, including the real
`copilot-cli` item, while Headroom continues to use Pi's explicit refresh
credential. Headroom still probes internet-password candidates, but this
machine has no matching `github.com` internet-password item.

This workaround depends on Headroom 0.30.0's current candidate-discovery
implementation. Recheck it during Headroom upgrades, and remove it if Headroom
starts short-circuiting discovery after finding the explicit environment
credential or adds a supported Keychain-disable setting.

## Subagents

`@tintinweb/pi-subagents` creates delegated Pi sessions through Pi's SDK, so the
same localhost Headroom service is reachable from parent and delegated
sessions. Routing still depends on the selected model:

- The built-in `general-purpose` definition has no pinned model. When it
  inherits a Headroom parent model, it can use `headroom-copilot/*` through the
  same service.
- Specialist definitions under `~/.config/pi/agent/agents/*.md` are currently
  pinned to models such as `github-copilot/gpt-5.5`,
  `github-copilot/gpt-5.4-mini`, `github-copilot/claude-opus-4.8`, and
  `github-copilot/claude-sonnet-4.6`. They remain direct.
- An explicitly delegated `headroom-copilot/<model>` uses Headroom if that alias
  exists and the proxy is healthy.

This is not fleet-wide proxying. Do not assume that starting a parent with
`hpi` rewrites every specialist's explicit model.

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| `hpi: command not found` | Current shell has not loaded the new zsh function. | Run `source "$HOME/.zshrc"` or open a new shell. |
| `headroom: command not found` in launchd logs | Headroom is missing or the plist `PATH` no longer includes its install location. | Run `command -v headroom`; compare it with the plist `EnvironmentVariables/PATH`; reinstall or redeploy deliberately. |
| Connection refused on `127.0.0.1:8787` | launchd job is unloaded, crashing, or another configuration changed the port. | Run the status and log commands above, then `launchctl kickstart -k "gui/$UID/com.stanwang.headroom-proxy"`. |
| `launchctl bootstrap` returns error 5 | Deployed plist may be a Stow symlink, malformed, already loaded, or otherwise rejected. | `plutil -lint` it, `bootout` the old label, deploy with `install -m 644`, and assert `test ! -L`. |
| Port 8787 is already in use | A manually started Headroom or stale process is competing with launchd. | Stop the manual process; keep one launchd-managed proxy. Use `lsof -nP -iTCP:8787 -sTCP:LISTEN`. |
| `/readyz` says rate limiter enabled | The deployed plist is stale or service was not restarted after adding `--no-rate-limit`. | Compare source and target plists, redeploy, restart, and recheck readiness. |
| `401` or token-exchange failure | Stored Pi credential is stale/revoked, service has an old credential in its environment, or upstream resolution is wrong. | Log in through direct Pi if necessary; run helper dry-run without printing secrets; restart the service. |
| Headroom works until a Pi re-login | The persistent process still holds the old refresh credential. | Restart launchd to reread `auth.json`. |
| Bare `pi` uses Headroom | The global setting drifted, usually because an older `hpi` function shared global settings or a direct Pi session selected Headroom. | Restore the direct invariant, reload the current `hpi` function, and keep login/configuration changes in regular Pi. |
| `hpi` picker shows only direct models | An old session/global scoped list is active, or the current shell has an old `hpi` definition. | Source `.zshrc`, start a new `hpi`, or switch the picker from `scoped` to `all`. |
| Headroom aliases are missing | `models.json` failed to parse, stow link is wrong, or provider auth availability failed. | Run `python3 -m json.tool "$HOME/dotfiles/pi/.config/pi/agent/models.json"` and `pi --list-models headroom-copilot`. |
| A Headroom alias returns model-not-supported | The manual mirror is stale or the Copilot account does not expose that model. | Compare direct account availability, Pi's current catalog, and `models.json`; remove or update only after protocol testing. |
| GPT works but Gemini fails | OpenAI Responses and Chat Completions use different wire paths and compatibility flags. | Confirm the alias API is `openai-completions` for Gemini and test the failing model independently. |
| Claude selected from `hpi` does not appear in Headroom stats | Expected: Claude entries are direct `github-copilot/claude-*`. | Use them directly or select a `headroom-copilot` GPT/Gemini alias. |
| Model calls `headroom_retrieve` and Pi reports an unknown tool | Service is not running with the intended lossless config. | Verify deployed flags and restart. `--lossless` in 0.30.0 disables CCR marker/tool injection. |
| macOS asks for a password after restart or inactivity | The deployed LaunchAgent is stale, or Headroom's Keychain discovery behavior changed. | Confirm the deployed plist contains `GITHUB_COPILOT_KEYCHAIN_SERVICE=__headroom_explicit_token_only__`, then see the Keychain section. `hpi` itself is not the caller. |
| Several delegated agents fail together | Shared proxy failure, GitHub throttling, or local resource pressure. | Check Headroom health/logs and GitHub errors; remember that `--no-rate-limit` disables only Headroom's limiter. |

## Upgrade and maintenance

### Headroom

Before upgrading, read the official
[Headroom changelog](https://github.com/chopratejas/headroom/blob/main/CHANGELOG.md)
and verify that all required flags and Copilot environment variables still
exist:

```sh
headroom --version
headroom proxy --help | grep -E -- '--no-rate-limit|--lossless|--no-subscription-tracking'
headroom-pi-copilot --dry-run
```

A future upgrade command is:

```sh
uv tool upgrade headroom-ai
```

Do not run it as blind maintenance. After any upgrade:

1. Record the installed version.
2. Reinspect Copilot token discovery and the Keychain behavior.
3. Revalidate `--lossless` still disables retrieval markers/tool injection.
4. Restart launchd.
5. Run readiness and one Headroom smoke test per wire API.

### Pi and model aliases

The 11 aliases are a manual snapshot, not a dynamic mirror. After upgrading Pi:

1. Read Pi's official [model configuration docs](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md).
2. Inspect the installed generated Copilot catalog at
   `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/github-copilot.models.js`.
3. Compare IDs, API types, context windows, token limits, reasoning maps,
   compatibility fields, headers, and account availability with
   [`../pi/.config/pi/agent/models.json`](../pi/.config/pi/agent/models.json).
4. Do not mirror models solely because they appear in the generated catalog;
   the account must expose them and the route must be tested.
5. Smoke-test at least one `openai-responses` and one `openai-completions` alias.
6. Recheck that bare `pi` is still direct and `hpi` remains scoped.

Pi reloads `models.json` when `/model` opens, per the official custom-model
documentation. A `.zshrc` change requires `source "$HOME/.zshrc"` or a new
shell. A plist change requires redeployment. A helper change requires a service
restart.

## Rollback and recovery

### Immediate per-chat fallback

Headroom is opt-in. Use direct Pi without changing or stopping anything:

```sh
pi --model github-copilot/gpt-5.6-sol
```

Once the direct default invariant is restored, bare `pi` is equivalent for a
new session:

```sh
pi
```

### Disable the persistent proxy

```sh
label=com.stanwang.headroom-proxy
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
launchctl disable "gui/$UID/$label"
```

This does not affect direct `github-copilot/*` models. `hpi` will fail until the
service is re-enabled and loaded.

Re-enable it:

```sh
label=com.stanwang.headroom-proxy
plist="$HOME/Library/LaunchAgents/$label.plist"
launchctl enable "gui/$UID/$label"
launchctl bootstrap "gui/$UID" "$plist"
```

### Recover after credential failure

1. Stop retrying through Headroom.
2. Start direct `pi` and complete GitHub Copilot `/login` if required.
3. Verify only that the `github-copilot` entry has nonempty access and refresh
   fields; never print them.
4. Restart Headroom:

```sh
launchctl kickstart -k "gui/$UID/com.stanwang.headroom-proxy"
```

5. Check `/readyz`, then run one Headroom smoke test.

### Recover the deployed plist

The repo source is authoritative:

```sh
label=com.stanwang.headroom-proxy
source_plist="$HOME/dotfiles/scripts/Library/LaunchAgents/$label.plist"
target_plist="$HOME/Library/LaunchAgents/$label.plist"

launchctl bootout "gui/$UID/$label" 2>/dev/null || true
install -m 644 "$source_plist" "$target_plist"
launchctl bootstrap "gui/$UID" "$target_plist"
```

Do not replace the real deployed file with a Stow symlink.

## Security notes

- Never commit or paste `~/.config/pi/agent/auth.json`, raw tokens, or the
  helper's runtime environment.
- Keep `auth.json` owner-readable only. Check metadata without reading contents:

  ```sh
  stat -f '%Sp %N' "$HOME/.config/pi/agent/auth.json"
  ```

- `hpi` copies `auth.json` into a mode-0700 temporary directory and sets the
  copied file to mode 0600. It removes the directory after a normal exit. An
  unclean shell termination can leave that copy under `$TMPDIR`; macOS normally
  clears its per-user temporary tree, but remove stale `hpi-agent.*` directories
  manually if needed.
- The dummy `apiKey` value `headroom-local` in `models.json` is not the Copilot
  secret. It only makes the local alias available to Pi.
- The launchd plist contains no secret. The helper exports the Pi refresh
  credential only into the Headroom child process environment.
- The proxy binds to `127.0.0.1`. Do not change it to `0.0.0.0` without adding
  inbound authentication and reviewing Headroom's network security model.
- Same-user processes may be able to inspect process state. Treat the local user
  account as the trust boundary.
- Headroom forwards prompts, tool output, and model responses to GitHub Copilot
  after local compression. Headroom being local does not make the upstream
  model call local.
- Logs can contain prompts, paths, model errors, and upstream response details.
  Review and redact before sharing them even though the helper does not
  intentionally log credentials.
- `--no-rate-limit` removes a local safety boundary. It does not grant more
  GitHub capacity and can make parallel-agent bursts hit upstream limits faster.

## Known limitations

- Installed Headroom 0.30.0 can trigger a Keychain password dialog during
  service startup/restart.
- The Headroom alias list is manually maintained and can drift from Pi's catalog
  or account availability.
- Claude models bypass Headroom.
- Specialist subagents pinned to `github-copilot/*` bypass Headroom.
- One localhost proxy is a shared failure point for all concurrent Headroom
  sessions.
- There is no automatic direct fallback when port 8787 is down.
- Parallel chats and inherited Headroom subagents share local CPU, memory,
  compression state, and GitHub quota.
- `--lossless` avoids CCR retrieval-tool dependence but intentionally gives up
  Headroom's retrieval-based reversible compression path.
- The tracked plist has account- and checkout-specific absolute paths.
- Changing Pi credentials does not hot-reload the running Headroom process.
- Direct Claude selection inside `hpi` can still exercise Pi's normal OAuth
  lifecycle and is not protected from direct-provider login friction.
- Login, package-setting, and other persistent configuration changes made inside
  `hpi` affect its temporary copies and are discarded; use regular `pi` for
  those operations.

## Primary implementation references

Local installed sources used to validate this guide:

- Pi custom models:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/docs/models.md`
- Pi custom providers:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/docs/custom-provider.md`
- Pi provider auth precedence and OAuth model rewriting:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/model-registry.js`
- Pi GitHub Copilot OAuth endpoint rewriting:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/utils/oauth/github-copilot.js`
- Pi Copilot Claude Bearer behavior:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/api/anthropic-messages.js`
- Pi generated Copilot model protocols:
  `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/github-copilot.models.js`
- Headroom Copilot auth and exchange:
  `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/copilot_auth.py`
- Headroom Keychain fallback:
  `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/copilot_macos_keychain.py`
- Headroom lossless mode and CCR disabling:
  `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/cli/proxy.py`
  and
  `~/.local/share/uv/tools/headroom-ai/lib/python3.12/site-packages/headroom/proxy/server.py`
- Subagent session/model behavior:
  `~/.config/pi/agent/npm/node_modules/@tintinweb/pi-subagents/dist/agent-runner.js`,
  `default-agents.js`, and `model-resolver.js`

Official references:

- [Pi custom models](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md)
- [Pi custom providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/custom-provider.md)
- [Headroom repository](https://github.com/chopratejas/headroom)
- [Headroom documentation](https://headroom-docs.vercel.app/docs)
- [Headroom changelog](https://github.com/chopratejas/headroom/blob/main/CHANGELOG.md)
