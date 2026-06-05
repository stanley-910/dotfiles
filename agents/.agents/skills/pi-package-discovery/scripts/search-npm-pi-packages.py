#!/usr/bin/env python3
"""Search npm for packages tagged with the pi-package keyword."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from typing import Any

REGISTRY_SEARCH_URL = "https://registry.npmjs.org/-/v1/search"


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "pi-package-discovery/0.1",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def short_date(value: str) -> str:
    if not value:
        return ""
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        return value[:10]


def clean_cell(value: Any, width: int) -> str:
    text = str(value or "").replace("|", "\\|").replace("\n", " ").strip()
    return text if len(text) <= width else text[: width - 1] + "…"


def package_row(obj: dict[str, Any]) -> dict[str, Any]:
    package = obj.get("package", {})
    downloads = obj.get("downloads", {})
    links = package.get("links", {})
    return {
        "updated": obj.get("updated") or package.get("date") or "",
        "name": package.get("name", ""),
        "version": package.get("version", ""),
        "description": package.get("description", ""),
        "weeklyDownloads": downloads.get("weekly", 0),
        "monthlyDownloads": downloads.get("monthly", 0),
        "npm": links.get("npm", ""),
        "repository": links.get("repository", ""),
        "score": obj.get("score", {}).get("final", 0),
    }


def print_markdown(rows: list[dict[str, Any]]) -> None:
    if not rows:
        print("No matching npm packages found.")
        return

    print("| Updated | Package | Weekly | Monthly | Description |")
    print("|---|---:|---:|---:|---|")
    for row in rows:
        package = f"{row['name']}@{row['version']}"
        print(
            "| {updated} | `{package}` | {weekly} | {monthly} | {description} |".format(
                updated=short_date(row["updated"]),
                package=clean_cell(package, 60),
                weekly=row["weeklyDownloads"],
                monthly=row["monthlyDownloads"],
                description=clean_cell(row["description"], 90),
            )
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", nargs="*", help="Capability to search for, e.g. mcp, web search, subagents")
    parser.add_argument("--limit", "-n", type=int, default=20, help="Number of results to print")
    parser.add_argument(
        "--sort",
        choices=("updated", "relevance"),
        default="updated",
        help="Sort final result table",
    )
    parser.add_argument("--json", action="store_true", help="Print raw normalized JSON rows")
    args = parser.parse_args()

    query = " ".join(args.query).strip()
    search_text = "keywords:pi-package" + (f" {query}" if query else "")
    # Fetch more than requested so local recency sorting has enough candidates.
    size = max(min(args.limit * 5, 250), args.limit)
    params = urllib.parse.urlencode({"text": search_text, "size": size, "from": 0})
    data = fetch_json(f"{REGISTRY_SEARCH_URL}?{params}")
    rows = [package_row(obj) for obj in data.get("objects", [])]

    if args.sort == "updated":
        rows.sort(key=lambda row: row.get("updated") or "", reverse=True)

    rows = rows[: args.limit]
    if args.json:
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        print_markdown(rows)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"npm search failed: {error}", file=sys.stderr)
        raise SystemExit(2)
