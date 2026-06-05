#!/usr/bin/env python3
"""Inspect npm metadata for a candidate Pi package without installing it."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from typing import Any

RISKY_SCRIPTS = {
    "preinstall",
    "install",
    "postinstall",
    "prepare",
    "prepack",
    "postpack",
    "prepublish",
    "prepublishOnly",
}


def fetch_package(name: str) -> dict[str, Any]:
    encoded = urllib.parse.quote(name, safe="")
    request = urllib.request.Request(
        f"https://registry.npmjs.org/{encoded}",
        headers={
            "Accept": "application/json",
            "User-Agent": "pi-package-discovery/0.1",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def as_list(mapping: dict[str, Any] | None) -> list[str]:
    if not mapping:
        return []
    return [f"{name}@{version}" for name, version in sorted(mapping.items())]


def print_json_block(title: str, value: Any) -> None:
    print(f"## {title}\n")
    if value:
        print("```json")
        print(json.dumps(value, indent=2, sort_keys=True))
        print("```\n")
    else:
        print("_None declared._\n")


def print_bullets(title: str, values: list[str], max_items: int = 40) -> None:
    print(f"## {title}\n")
    if not values:
        print("_None declared._\n")
        return
    for value in values[:max_items]:
        print(f"- `{value}`")
    if len(values) > max_items:
        print(f"- … {len(values) - max_items} more")
    print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", help="npm package name, e.g. pi-mcp-adapter or @scope/name")
    parser.add_argument("--version", help="Specific version to inspect. Defaults to dist-tags.latest")
    parser.add_argument("--json", action="store_true", help="Print normalized JSON summary")
    args = parser.parse_args()

    package = fetch_package(args.package)
    version = args.version or package.get("dist-tags", {}).get("latest")
    if not version:
        print("Could not determine latest version", file=sys.stderr)
        return 2

    versions = package.get("versions", {})
    manifest = versions.get(version)
    if not manifest:
        print(f"Version not found: {version}", file=sys.stderr)
        return 2

    scripts = manifest.get("scripts", {}) or {}
    risky_scripts = {key: scripts[key] for key in sorted(scripts) if key in RISKY_SCRIPTS}
    dependencies = as_list(manifest.get("dependencies"))
    peer_dependencies = as_list(manifest.get("peerDependencies"))
    optional_dependencies = as_list(manifest.get("optionalDependencies"))
    pi_manifest = manifest.get("pi")
    dist = manifest.get("dist", {}) or {}
    links = {
        "homepage": manifest.get("homepage"),
        "repository": manifest.get("repository"),
        "bugs": manifest.get("bugs"),
        "npm": f"https://www.npmjs.com/package/{urllib.parse.quote(args.package, safe='@')}",
    }
    summary = {
        "name": manifest.get("name"),
        "version": manifest.get("version"),
        "description": manifest.get("description"),
        "license": manifest.get("license"),
        "published": package.get("time", {}).get(version),
        "keywords": manifest.get("keywords", []),
        "links": links,
        "pi": pi_manifest,
        "scripts": scripts,
        "riskyScripts": risky_scripts,
        "dependencyCount": len(dependencies),
        "peerDependencyCount": len(peer_dependencies),
        "optionalDependencyCount": len(optional_dependencies),
        "tarball": dist.get("tarball"),
        "unpackedSize": dist.get("unpackedSize"),
    }

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0

    print(f"# `{summary['name']}@{summary['version']}`\n")
    print(summary.get("description") or "_No description._")
    print()
    print(f"- Published: `{summary.get('published') or 'unknown'}`")
    print(f"- License: `{summary.get('license') or 'unknown'}`")
    print(f"- Unpacked size: `{summary.get('unpackedSize') or 'unknown'}` bytes")
    print(f"- Tarball: {summary.get('tarball') or '_unknown_'}")
    print()

    print_json_block("Pi manifest", pi_manifest)
    print_json_block("Lifecycle/install scripts", scripts)

    if risky_scripts:
        print("## Risk flags\n")
        print("- Package declares npm lifecycle scripts. Review before install:")
        for key, value in risky_scripts.items():
            print(f"  - `{key}`: `{value}`")
        print()
    else:
        print("## Risk flags\n")
        print("- No common npm install/lifecycle scripts declared in package metadata.\n")

    print_bullets("Dependencies", dependencies)
    print_bullets("Peer dependencies", peer_dependencies)
    print_bullets("Optional dependencies", optional_dependencies)

    print("## Links\n")
    for label, value in links.items():
        if value:
            print(f"- {label}: {value}")
    print()

    print("## Suggested gate\n")
    print("Ask before continuing: `metadata only`, `audit code`, `try once with pi -e`, or `install permanently`.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"npm metadata fetch failed: {error}", file=sys.stderr)
        raise SystemExit(2)
