#!/usr/bin/env python3
"""Audit drift between this Mac and the dotfiles bootstrap scripts.

Read-only against system state. Writes a Markdown report plus a private JSON
snapshot so future runs can show machine-to-machine drift.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

KNOWN_DEFAULT_DOMAINS = [
    "NSGlobalDomain",
    "com.apple.AppleMultitouchTrackpad",
    "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    "com.apple.CrashReporter",
    "com.apple.LaunchServices",
    "com.apple.controlcenter",
    "com.apple.desktopservices",
    "com.apple.dock",
    "com.apple.finder",
    "com.apple.screencapture",
    "com.apple.symbolichotkeys",
    "com.caldis.Mos",
    "net.imput.helium",
    "pbs",
]

SYSTEM_APP_NAMES = {
    "App Store.app",
    "Automator.app",
    "Books.app",
    "Calculator.app",
    "Calendar.app",
    "Chess.app",
    "Contacts.app",
    "Dictionary.app",
    "FaceTime.app",
    "FindMy.app",
    "Font Book.app",
    "Freeform.app",
    "Home.app",
    "Image Capture.app",
    "Launchpad.app",
    "Mail.app",
    "Maps.app",
    "Messages.app",
    "Mission Control.app",
    "Music.app",
    "News.app",
    "Notes.app",
    "Photo Booth.app",
    "Photos.app",
    "Podcasts.app",
    "Preview.app",
    "QuickTime Player.app",
    "Reminders.app",
    "Safari.app",
    "Shortcuts.app",
    "Siri.app",
    "Stickies.app",
    "Stocks.app",
    "System Settings.app",
    "TV.app",
    "TextEdit.app",
    "Time Machine.app",
    "Utilities",
    "VoiceMemos.app",
    "Weather.app",
}


def run(cmd: list[str], timeout: int = 30, text: bool = True) -> dict[str, Any]:
    if "/" not in cmd[0] and shutil.which(cmd[0]) is None:
        return {
            "ok": False,
            "missing": True,
            "returncode": 127,
            "stdout": "" if text else b"",
            "stderr": f"{cmd[0]} not found",
        }
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=text,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "ok": False,
            "missing": False,
            "returncode": None,
            "stdout": exc.stdout or ("" if text else b""),
            "stderr": f"timed out after {timeout}s",
        }
    return {
        "ok": proc.returncode == 0,
        "missing": False,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def lines(cmd: list[str], timeout: int = 30) -> list[str]:
    result = run(cmd, timeout=timeout)
    if not result["ok"]:
        return []
    return sorted({line.strip() for line in result["stdout"].splitlines() if line.strip()})


def jsonable(value: Any) -> Any:
    if isinstance(value, bytes):
        return {"__bytes_hex__": value.hex()}
    if isinstance(value, dict):
        return {str(k): jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [jsonable(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return repr(value)


def stable_hash(value: Any) -> str:
    encoded = json.dumps(jsonable(value), sort_keys=True, ensure_ascii=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001 - report and continue with no baseline
        print(f"warning: could not read previous snapshot {path}: {exc}", file=sys.stderr)
        return None


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def parse_brewfiles(repo: Path) -> dict[str, dict[str, list[str]]]:
    out: dict[str, dict[str, list[str]]] = {}
    for brewfile in sorted(repo.glob("Brewfile*")):
        if not brewfile.is_file() or brewfile.name.endswith(".lock.json"):
            continue
        entry = {"brew": [], "cask": [], "tap": []}
        for raw in brewfile.read_text(errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = re.match(r"^(brew|cask|tap)\s+[\"']([^\"']+)[\"']", line)
            if match:
                entry[match.group(1)].append(match.group(2))
        out[brewfile.name] = {key: sorted(set(value)) for key, value in entry.items()}
    return out


def parse_prepper_casks(prepper: Path) -> list[str]:
    if not prepper.exists():
        return []
    text = prepper.read_text(errors="replace")
    match = re.search(r"local\s+casks=\(\s*(.*?)^\s*\)", text, re.M | re.S)
    if not match:
        return []
    casks: list[str] = []
    for raw in match.group(1).splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        casks.extend(re.findall(r"[A-Za-z0-9_.+@-]+", line))
    return sorted(set(casks))


def logical_shell_lines(text: str) -> list[tuple[int, str]]:
    logical: list[tuple[int, str]] = []
    buf: list[str] = []
    start = 1
    for line_no, raw in enumerate(text.splitlines(), start=1):
        stripped = raw.strip()
        if not buf and (not stripped or stripped.startswith("#")):
            continue
        if not buf:
            start = line_no
        continued = raw.rstrip().endswith("\\")
        piece = raw.rstrip()
        if continued:
            piece = piece[:-1]
        buf.append(piece.strip())
        if not continued:
            joined = " ".join(part for part in buf if part)
            if joined:
                logical.append((start, joined))
            buf = []
    if buf:
        logical.append((start, " ".join(part for part in buf if part)))
    return logical


def parse_defaults_commands(prepper: Path) -> list[dict[str, Any]]:
    if not prepper.exists():
        return []
    commands: list[dict[str, Any]] = []
    for line_no, command in logical_shell_lines(prepper.read_text(errors="replace")):
        if "defaults write" not in command and "defaults delete" not in command:
            continue
        try:
            tokens = shlex.split(command, comments=True, posix=True)
        except ValueError as exc:
            commands.append(
                {
                    "line": line_no,
                    "raw": command,
                    "action": "complex",
                    "comparable": False,
                    "reason": f"could not parse shell quoting: {exc}",
                }
            )
            continue
        if "defaults" not in tokens:
            continue
        idx = tokens.index("defaults")
        if len(tokens) <= idx + 3:
            continue
        action = tokens[idx + 1]
        if action not in {"write", "delete"}:
            continue
        domain = tokens[idx + 2]
        key = tokens[idx + 3]
        rest = tokens[idx + 4 :]
        raw = " ".join(tokens[idx:])
        if "$" in domain or "$" in key or any("$" in token for token in rest):
            commands.append(
                {
                    "line": line_no,
                    "raw": raw,
                    "action": action,
                    "domain": domain,
                    "key": key,
                    "comparable": False,
                    "reason": "contains shell variable or command substitution",
                }
            )
            continue
        if action == "delete":
            commands.append(
                {
                    "line": line_no,
                    "raw": raw,
                    "action": action,
                    "domain": domain,
                    "key": key,
                    "expected_absent": True,
                    "comparable": True,
                }
            )
            continue
        value_type = "raw"
        expected: str | None = None
        comparable = False
        reason = "raw or complex defaults value"
        if rest and rest[0] in {"-bool", "-int", "-float", "-string", "-data"} and len(rest) >= 2:
            value_type = rest[0].lstrip("-")
            expected = rest[1]
            comparable = True
            reason = ""
        elif rest and rest[0] == "-dict-add":
            value_type = "dict-add"
            expected = " ".join(rest[1:])
            reason = "dict-add changes only part of a dictionary"
        else:
            expected = " ".join(rest)
        commands.append(
            {
                "line": line_no,
                "raw": raw,
                "action": action,
                "domain": domain,
                "key": key,
                "value_type": value_type,
                "expected": expected,
                "comparable": comparable,
                "reason": reason,
            }
        )
    return commands


def parse_repo(repo: Path) -> dict[str, Any]:
    brewfiles = parse_brewfiles(repo)
    prepper_casks = parse_prepper_casks(repo / "prepper.sh")
    defaults_commands = parse_defaults_commands(repo / "prepper.sh")
    return {
        "brewfiles": brewfiles,
        "prepper_casks": prepper_casks,
        "defaults_commands": defaults_commands,
    }


def collect_brew() -> dict[str, Any]:
    installed_casks = lines(["brew", "list", "--cask", "-1"])
    installed_formulae = lines(["brew", "list", "--formula", "-1"])
    leaves = lines(["brew", "leaves"])
    taps = lines(["brew", "tap"])
    cask_apps = cask_artifact_apps(installed_casks)
    return {
        "available": shutil.which("brew") is not None,
        "formulae": installed_formulae,
        "leaves": leaves,
        "casks": installed_casks,
        "taps": taps,
        "cask_apps": cask_apps,
    }


def cask_artifact_apps(casks: list[str]) -> dict[str, list[str]]:
    if not casks:
        return {}
    result = run(["brew", "info", "--cask", "--json=v2", *casks], timeout=120)
    if not result["ok"]:
        return {}
    try:
        payload = json.loads(result["stdout"])
    except json.JSONDecodeError:
        return {}
    out: dict[str, list[str]] = {}
    for cask in payload.get("casks", []):
        token = cask.get("token")
        apps: list[str] = []
        for artifact in cask.get("artifacts", []):
            if not isinstance(artifact, dict) or "app" not in artifact:
                continue
            value = artifact["app"]
            if isinstance(value, list):
                apps.extend(str(item) for item in value if str(item).endswith(".app"))
            elif isinstance(value, str) and value.endswith(".app"):
                apps.append(value)
        if token:
            out[str(token)] = sorted(set(apps))
    return out


def app_bundle_id(app: Path) -> str | None:
    plist = app / "Contents" / "Info.plist"
    if plist.exists():
        try:
            with plist.open("rb") as handle:
                info = plistlib.load(handle)
            bundle_id = info.get("CFBundleIdentifier")
            if bundle_id:
                return str(bundle_id)
        except Exception:
            pass
    result = run(["mdls", "-raw", "-name", "kMDItemCFBundleIdentifier", str(app)], timeout=10)
    if result["ok"]:
        value = result["stdout"].strip()
        if value and value != "(null)":
            return value
    return None


def collect_apps() -> list[dict[str, str]]:
    apps: list[dict[str, str]] = []
    seen: set[str] = set()
    for root in [Path("/Applications"), Path.home() / "Applications"]:
        if not root.exists():
            continue
        for app in sorted(root.glob("*.app")):
            key = str(app.resolve())
            if key in seen:
                continue
            seen.add(key)
            apps.append(
                {
                    "name": app.name,
                    "path": str(app),
                    "bundle_id": app_bundle_id(app) or "",
                }
            )
    return sorted(apps, key=lambda item: (item["name"].lower(), item["path"]))


def collect_language_tools() -> dict[str, Any]:
    tools: dict[str, Any] = {}

    npm = run(["npm", "ls", "-g", "--depth=0", "--json"], timeout=45)
    if npm["ok"]:
        try:
            payload = json.loads(npm["stdout"])
            tools["npm"] = sorted((payload.get("dependencies") or {}).keys())
        except json.JSONDecodeError:
            tools["npm"] = []

    pnpm = run(["pnpm", "-g", "ls", "--depth", "0", "--json"], timeout=45)
    if pnpm["ok"]:
        try:
            payload = json.loads(pnpm["stdout"])
            packages: list[str] = []
            if isinstance(payload, list):
                for project in payload:
                    packages.extend((project.get("dependencies") or {}).keys())
            tools["pnpm"] = sorted(set(packages))
        except json.JSONDecodeError:
            tools["pnpm"] = []

    yarn = run(["yarn", "global", "list", "--json"], timeout=45)
    if yarn["ok"]:
        packages = []
        for raw in yarn["stdout"].splitlines():
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            data = payload.get("data")
            if isinstance(data, str):
                match = re.search(r"info \"([^\"]+)@", data)
                if match:
                    packages.append(match.group(1))
        tools["yarn"] = sorted(set(packages))

    pipx = run(["pipx", "list", "--json"], timeout=45)
    if pipx["ok"]:
        try:
            payload = json.loads(pipx["stdout"])
            tools["pipx"] = sorted((payload.get("venvs") or {}).keys())
        except json.JSONDecodeError:
            tools["pipx"] = []

    uv = run(["uv", "tool", "list"], timeout=45)
    if uv["ok"]:
        packages = []
        for raw in uv["stdout"].splitlines():
            line = raw.strip()
            if line and not line.startswith("-") and " " in line:
                packages.append(line.split()[0])
        tools["uv"] = sorted(set(packages))

    cargo = run(["cargo", "install", "--list"], timeout=45)
    if cargo["ok"]:
        packages = []
        for raw in cargo["stdout"].splitlines():
            if raw and not raw.startswith(" ") and " v" in raw:
                packages.append(raw.split()[0])
        tools["cargo"] = sorted(set(packages))

    gem = run(["gem", "list", "--local"], timeout=45)
    if gem["ok"]:
        packages = []
        for raw in gem["stdout"].splitlines():
            match = re.match(r"^([A-Za-z0-9_.-]+)\s", raw)
            if match:
                packages.append(match.group(1))
        tools["gem"] = sorted(set(packages))

    return tools


def compare_default(command: dict[str, Any]) -> dict[str, Any]:
    if not command.get("comparable"):
        return {**command, "status": "skipped"}
    domain = command["domain"]
    key = command["key"]
    result = run(["defaults", "read", domain, key], timeout=10)
    actual = result["stdout"].strip() if result["ok"] else ""
    if command.get("expected_absent"):
        return {
            **command,
            "actual": actual,
            "status": "match" if not result["ok"] else "mismatch",
        }
    if not result["ok"]:
        return {**command, "actual": "<missing>", "status": "mismatch"}
    expected = str(command.get("expected", ""))
    value_type = command.get("value_type")
    matched = False
    if value_type == "bool":
        matched = normalize_bool(expected) == normalize_bool(actual)
    elif value_type == "int":
        matched = parse_int(expected) == parse_int(actual)
    elif value_type == "float":
        left = parse_float(expected)
        right = parse_float(actual)
        matched = left is not None and right is not None and abs(left - right) < 0.000001
    elif value_type == "string":
        matched = actual == expected
    elif value_type == "data":
        actual_hex = re.sub(r"[^0-9a-fA-F]", "", actual).lower()
        expected_hex = re.sub(r"[^0-9a-fA-F]", "", expected).lower()
        matched = bool(expected_hex) and expected_hex in actual_hex
    return {
        **command,
        "actual": actual,
        "status": "match" if matched else "mismatch",
    }


def normalize_bool(value: str) -> bool | None:
    low = value.strip().lower()
    if low in {"1", "true", "yes", "on"}:
        return True
    if low in {"0", "false", "no", "off"}:
        return False
    return None


def parse_int(value: str) -> int | None:
    try:
        return int(value.strip())
    except ValueError:
        return None


def parse_float(value: str) -> float | None:
    try:
        return float(value.strip())
    except ValueError:
        return None


def export_defaults_domain(domain: str) -> dict[str, Any]:
    result = run(["defaults", "export", domain, "-"], timeout=15, text=False)
    if not result["ok"]:
        return {
            "ok": False,
            "hash": "",
            "value": None,
            "error": (result["stderr"] or b"").decode(errors="replace").strip(),
        }
    try:
        value = plistlib.loads(result["stdout"])
    except Exception as exc:  # noqa: BLE001 - retain evidence without crashing
        return {"ok": False, "hash": "", "value": None, "error": f"plist parse failed: {exc}"}
    value = jsonable(value)
    return {"ok": True, "hash": stable_hash(value), "value": value, "error": ""}


def collect_defaults(commands: list[dict[str, Any]], scope: str) -> dict[str, Any]:
    declared = [compare_default(command) for command in commands]
    domains: dict[str, Any] = {}
    if scope == "known":
        for domain in KNOWN_DEFAULT_DOMAINS:
            domains[domain] = export_defaults_domain(domain)
    return {"declared": declared, "known_domains": domains}


def collect_current(repo_declarations: dict[str, Any], defaults_scope: str) -> dict[str, Any]:
    return {
        "brew": collect_brew(),
        "apps": collect_apps(),
        "language_tools": collect_language_tools(),
        "defaults": collect_defaults(repo_declarations["defaults_commands"], defaults_scope),
    }


def union_brew(repo: dict[str, Any], kind: str) -> set[str]:
    values: set[str] = set()
    for data in repo["brewfiles"].values():
        values.update(data.get(kind, []))
    if kind == "cask":
        values.update(repo.get("prepper_casks", []))
    return values


def set_at(snapshot: dict[str, Any] | None, path: list[str]) -> set[str]:
    if snapshot is None:
        return set()
    node: Any = snapshot
    for key in path:
        if not isinstance(node, dict):
            return set()
        node = node.get(key)
    if isinstance(node, list):
        return {str(item) for item in node}
    return set()


def apps_as_ids(apps: list[dict[str, str]]) -> set[str]:
    ids = set()
    for app in apps:
        bundle_id = app.get("bundle_id") or ""
        name = app.get("name") or ""
        ids.add(f"{name} ({bundle_id})" if bundle_id else name)
    return ids


def md_list(items: list[str] | set[str], empty: str = "None", limit: int = 40) -> str:
    ordered = sorted(items)
    if not ordered:
        return f"- {empty}\n"
    visible = ordered[:limit]
    body = "".join(f"- `{item}`\n" for item in visible)
    if len(ordered) > limit:
        body += f"- …and {len(ordered) - limit} more\n"
    return body


def diff_known_domains(previous: dict[str, Any] | None, current: dict[str, Any]) -> list[dict[str, Any]]:
    if previous is None:
        return []
    prev_domains = previous.get("current", {}).get("defaults", {}).get("known_domains", {})
    cur_domains = current.get("defaults", {}).get("known_domains", {})
    diffs: list[dict[str, Any]] = []
    for domain, cur in sorted(cur_domains.items()):
        prev = prev_domains.get(domain)
        if not prev or prev.get("hash") == cur.get("hash"):
            continue
        prev_value = prev.get("value")
        cur_value = cur.get("value")
        added: list[str] = []
        removed: list[str] = []
        changed: list[str] = []
        if isinstance(prev_value, dict) and isinstance(cur_value, dict):
            prev_keys = set(prev_value.keys())
            cur_keys = set(cur_value.keys())
            added = sorted(cur_keys - prev_keys)
            removed = sorted(prev_keys - cur_keys)
            for key in sorted(prev_keys & cur_keys):
                if stable_hash(prev_value[key]) != stable_hash(cur_value[key]):
                    changed.append(key)
        diffs.append({"domain": domain, "added": added, "removed": removed, "changed": changed})
    return diffs


def language_diffs(previous: dict[str, Any] | None, current: dict[str, Any]) -> dict[str, dict[str, set[str]]]:
    if previous is None:
        return {}
    prev_tools = previous.get("current", {}).get("language_tools", {})
    cur_tools = current.get("language_tools", {})
    managers = sorted(set(prev_tools) | set(cur_tools))
    diffs: dict[str, dict[str, set[str]]] = {}
    for manager in managers:
        prev = set(prev_tools.get(manager, []))
        cur = set(cur_tools.get(manager, []))
        added = cur - prev
        removed = prev - cur
        if added or removed:
            diffs[manager] = {"added": added, "removed": removed}
    return diffs


def generate_report(
    repo_path: Path,
    snapshot: dict[str, Any],
    previous: dict[str, Any] | None,
    snapshot_path: Path,
) -> str:
    repo = snapshot["repo_declarations"]
    current = snapshot["current"]
    brew = current["brew"]

    # brew leaves emits tap-qualified names (modem-dev/tap/hunk) while
    # declarations and `brew list` use short names — compare short names.
    def _short(name: str) -> str:
        return name.rsplit("/", 1)[-1]

    declared_brews = {_short(n) for n in union_brew(repo, "brew")}
    declared_casks = {_short(n) for n in union_brew(repo, "cask")}
    installed_formulae = {_short(n) for n in brew.get("formulae", [])}
    installed_leaves = {_short(n) for n in brew.get("leaves", [])}
    installed_casks = {_short(n) for n in brew.get("casks", [])}

    missing_brews = declared_brews - installed_formulae
    extra_leaves = installed_leaves - declared_brews
    missing_casks = declared_casks - installed_casks
    extra_casks = installed_casks - declared_casks

    prev_apps = apps_as_ids(previous.get("current", {}).get("apps", [])) if previous else set()
    cur_apps = apps_as_ids(current.get("apps", []))
    added_apps = cur_apps - prev_apps if previous else set()
    removed_apps = prev_apps - cur_apps if previous else set()

    cask_app_names = {name for names in brew.get("cask_apps", {}).values() for name in names}
    installed_cask_tokens = set(brew.get("casks", []))
    possible_non_brew_apps = {
        app["name"]
        for app in current.get("apps", [])
        if app["name"] not in SYSTEM_APP_NAMES
        and not is_probably_cask_app(app["name"], cask_app_names, installed_cask_tokens)
    }

    default_mismatches = [
        item for item in current["defaults"]["declared"] if item.get("status") == "mismatch"
    ]
    default_skipped = [
        item for item in current["defaults"]["declared"] if item.get("status") == "skipped"
    ]
    domain_diffs = diff_known_domains(previous, current)
    lang_diffs = language_diffs(previous, current)

    lines_out: list[str] = []
    lines_out.append("# Dotfiles Drift Audit\n")
    lines_out.append(f"- Repo: `{repo_path}`\n")
    lines_out.append(f"- Generated: `{snapshot['metadata']['generated_at']}`\n")
    lines_out.append(f"- Snapshot written: `{snapshot_path}`\n")
    if previous:
        lines_out.append(f"- Previous snapshot: `{previous['metadata'].get('generated_at', 'unknown')}`\n")
    else:
        lines_out.append("- Previous snapshot: none; this run establishes the baseline\n")

    lines_out.append("\n## Executive summary\n\n")
    lines_out.append(f"- Extra Homebrew leaves not declared: **{len(extra_leaves)}**\n")
    lines_out.append(f"- Missing declared Homebrew formulae: **{len(missing_brews)}**\n")
    lines_out.append(f"- Extra casks not declared: **{len(extra_casks)}**\n")
    lines_out.append(f"- Missing declared casks: **{len(missing_casks)}**\n")
    lines_out.append(f"- Possible non-Homebrew apps: **{len(possible_non_brew_apps)}**\n")
    lines_out.append(f"- Declared defaults mismatches: **{len(default_mismatches)}**\n")
    lines_out.append(f"- Known defaults domains changed since previous snapshot: **{len(domain_diffs)}**\n")

    lines_out.append("\n## Homebrew formula drift\n\n")
    lines_out.append("### Extra installed Homebrew leaves\n\n")
    lines_out.append(md_list(extra_leaves, "No extra top-level formulae detected"))
    lines_out.append("\n### Missing declared Homebrew formulae\n\n")
    lines_out.append(md_list(missing_brews, "All declared formulae are installed"))
    if extra_leaves:
        lines_out.append("\n### Candidate Brewfile patch\n\n")
        target = "Brewfile.external" if "Brewfile.external" in repo.get("brewfiles", {}) else "Brewfile"
        lines_out.append(f"Review before adding to `{target}`:\n\n")
        lines_out.append("```ruby\n")
        for name in sorted(extra_leaves):
            lines_out.append(f"brew \"{name}\"\n")
        lines_out.append("```\n")

    lines_out.append("\n## Homebrew cask drift\n\n")
    lines_out.append("### Extra installed casks\n\n")
    lines_out.append(md_list(extra_casks, "No extra casks detected"))
    lines_out.append("\n### Missing declared casks\n\n")
    lines_out.append(md_list(missing_casks, "All declared casks are installed"))
    if extra_casks:
        lines_out.append("\n### Candidate `prepper.sh` cask-array additions\n\n")
        lines_out.append("```bash\n")
        for name in sorted(extra_casks):
            lines_out.append(f"        {name}  # TODO: why this belongs on every fresh Mac\n")
        lines_out.append("```\n")

    lines_out.append("\n## Mac app drift\n\n")
    lines_out.append("### Possible non-Homebrew apps\n\n")
    lines_out.append(md_list(possible_non_brew_apps, "No obvious non-Homebrew apps detected"))
    if previous:
        lines_out.append("\n### Added apps since previous snapshot\n\n")
        lines_out.append(md_list(added_apps, "No apps added since previous snapshot"))
        lines_out.append("\n### Removed apps since previous snapshot\n\n")
        lines_out.append(md_list(removed_apps, "No apps removed since previous snapshot"))

    lines_out.append("\n## Language tool drift\n\n")
    if not previous:
        lines_out.append("- No previous snapshot; language tool baseline established today.\n")
    elif not lang_diffs:
        lines_out.append("- No language-manager global tool changes since previous snapshot.\n")
    else:
        for manager, diff in lang_diffs.items():
            lines_out.append(f"\n### `{manager}`\n\n")
            lines_out.append("Added:\n")
            lines_out.append(md_list(diff["added"], "None"))
            lines_out.append("Removed:\n")
            lines_out.append(md_list(diff["removed"], "None"))
        lines_out.append(
            "\nIf these tools must survive a fresh machine, add an explicit bootstrap section "
            "or document the manager-specific install command.\n"
        )

    lines_out.append("\n## macOS defaults drift\n\n")
    lines_out.append("### Declared defaults mismatches\n\n")
    if default_mismatches:
        lines_out.append("| Line | Domain | Key | Expected | Actual |\n")
        lines_out.append("| ---: | --- | --- | --- | --- |\n")
        for item in default_mismatches[:80]:
            expected = "<absent>" if item.get("expected_absent") else item.get("expected", "")
            actual = item.get("actual", "")
            lines_out.append(
                f"| {item.get('line', '')} | `{item.get('domain', '')}` | "
                f"`{item.get('key', '')}` | `{escape_md(shorten(str(expected)))}` | "
                f"`{escape_md(shorten(str(actual)))}` |\n"
            )
        if len(default_mismatches) > 80:
            lines_out.append(f"\n…and {len(default_mismatches) - 80} more mismatches.\n")
    else:
        lines_out.append("- All comparable `prepper.sh` defaults match current values.\n")

    lines_out.append("\n### Defaults commands needing manual review\n\n")
    if default_skipped:
        for item in default_skipped[:40]:
            lines_out.append(
                f"- Line {item.get('line')}: `{escape_md(item.get('raw', ''))}` "
                f"— {item.get('reason', 'not comparable')}\n"
            )
        if len(default_skipped) > 40:
            lines_out.append(f"- …and {len(default_skipped) - 40} more\n")
    else:
        lines_out.append("- No complex defaults commands were skipped.\n")

    lines_out.append("\n### Known defaults domain changes since previous snapshot\n\n")
    if not previous:
        lines_out.append("- No previous snapshot; known-domain baseline established today.\n")
    elif not domain_diffs:
        lines_out.append("- No known defaults domain changes detected.\n")
    else:
        for diff in domain_diffs:
            lines_out.append(f"- `{diff['domain']}`\n")
            if diff["added"]:
                lines_out.append(f"  - Added keys: {', '.join(f'`{escape_md(k)}`' for k in diff['added'][:20])}\n")
            if diff["removed"]:
                lines_out.append(f"  - Removed keys: {', '.join(f'`{escape_md(k)}`' for k in diff['removed'][:20])}\n")
            if diff["changed"]:
                lines_out.append(f"  - Changed keys: {', '.join(f'`{escape_md(k)}`' for k in diff['changed'][:20])}\n")

    lines_out.append("\n## Next actions\n\n")
    lines_out.append("1. Decide which `Extra installed` items are intentional fresh-Mac requirements.\n")
    lines_out.append("2. Apply only the reviewed patch snippets to dotfiles source files.\n")
    lines_out.append("3. For defaults mismatches, decide whether the current machine or `prepper.sh` is the source of truth.\n")
    lines_out.append("4. Re-run this audit after edits to refresh the snapshot and confirm reduced drift.\n")

    return "".join(lines_out)


def normalize_appish(value: str) -> str:
    value = value.removesuffix(".app").replace("browser", "")
    return re.sub(r"[^a-z0-9]", "", value.lower())


def is_probably_cask_app(app_name: str, cask_app_names: set[str], cask_tokens: set[str]) -> bool:
    if app_name in cask_app_names:
        return True
    app_norm = normalize_appish(app_name)
    for token in cask_tokens:
        token_norm = normalize_appish(token)
        if len(token_norm) >= 4 and (app_norm == token_norm or app_norm in token_norm or token_norm in app_norm):
            return True
    return False


def shorten(value: str, limit: int = 220) -> str:
    value = value.replace("\n", "\\n")
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "…"


def escape_md(value: str) -> str:
    return value.replace("`", "\\`").replace("\n", "\\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="dotfiles repo root (default: current directory)")
    parser.add_argument(
        "--state-dir",
        default=str(Path.home() / ".local/state/dotfiles-drift"),
        help="private snapshot directory",
    )
    parser.add_argument(
        "--report",
        default=None,
        help="Markdown report path (default: <state-dir>/reports/<timestamp>.md)",
    )
    parser.add_argument(
        "--defaults-scope",
        choices=["script", "known"],
        default="known",
        help="script = declared keys only; known = declared keys plus known domain snapshots",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).expanduser().resolve()
    if not (repo / "prepper.sh").exists() or not (repo / "bootstrap.sh").exists():
        print(f"error: {repo} does not look like the dotfiles repo", file=sys.stderr)
        return 2

    state_dir = Path(args.state_dir).expanduser()
    snapshots_dir = state_dir / "snapshots"
    latest_path = state_dir / "latest.json"
    previous = read_json(latest_path)

    generated = dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="seconds")
    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    repo_declarations = parse_repo(repo)
    current = collect_current(repo_declarations, args.defaults_scope)
    snapshot = {
        "metadata": {
            "generated_at": generated,
            "repo": str(repo),
            "defaults_scope": args.defaults_scope,
            "script_version": 1,
        },
        "repo_declarations": repo_declarations,
        "current": current,
    }

    snapshot_path = snapshots_dir / f"{timestamp}.json"
    write_json(snapshot_path, snapshot)
    write_json(latest_path, snapshot)

    report_path = Path(args.report).expanduser() if args.report else state_dir / "reports" / f"{timestamp}.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = generate_report(repo, snapshot, previous, snapshot_path)
    report_path.write_text(report)

    print(f"Report: {report_path}")
    print(f"Snapshot: {snapshot_path}")
    print(f"Latest snapshot: {latest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
