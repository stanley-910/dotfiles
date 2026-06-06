#!/usr/bin/env python3
"""Find relevant pages in a camera manual, optionally render them for visual Read.

This helper is intentionally conservative: it uses pdftotext to rank candidate
PDF leaf pages, then pdftoppm to render only a small selected set. It prints the
image paths for an agent to inspect with the Read tool and a cleanup command to
run after inspection.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_PDF = Path(
    "/Users/stanwang/Library/Mobile Documents/iCloud~md~obsidian/Documents/"
    "codex-cloud/sources/fujifilm/x-t30-iii_manual_en_s_f.pdf"
)

STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "can", "do", "does",
    "for", "from", "how", "i", "in", "is", "it", "its", "me", "of", "on",
    "or", "page", "show", "tell", "the", "this", "to", "what", "when",
    "where", "which", "with", "you",
}

CONTROL_TERMS = [
    "button", "dial", "lever", "connector", "viewfinder", "monitor",
    "battery", "slot", "lamp", "sensor", "shutter", "focus", "flash",
    "shoe", "microphone", "selector", "menu", "display", "touch",
]

SAFETY_TERMS = [
    "warning", "electric shock", "small children", "traffic accident",
    "injury", "household cleaners", "flammable", "disposal",
]


def run(cmd: list[str], *, text: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=text)


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        print(f"ERROR: required tool not found on PATH: {name}", file=sys.stderr)
        print("Install Poppler first (macOS: brew install poppler), or ask before installing.", file=sys.stderr)
        sys.exit(2)


def extract_pages(pdf: Path) -> list[str]:
    require_tool("pdftotext")
    cp = run(["pdftotext", "-layout", str(pdf), "-"])
    return cp.stdout.split("\f")


def meaningful_terms(query: str) -> list[str]:
    return [t for t in re.findall(r"[a-z0-9]+", query.lower()) if t not in STOPWORDS and len(t) > 1]


def snippet(lines: list[str], limit: int = 14) -> str:
    return "\n".join(lines[:limit])[:900]


def score_pages(pages: list[str], query: str) -> list[tuple[float, int, list[str], str]]:
    terms = meaningful_terms(query)
    query_low = query.lower()
    phrase_candidates = []
    # Prefer quoted phrases, then useful title-ish chunks.
    phrase_candidates.extend(re.findall(r'"([^"]+)"', query))
    if "parts" in query_low and "camera" in query_low:
        phrase_candidates.append("parts of the camera")
    if "film" in query_low and "simulation" in query_low:
        phrase_candidates.append("film simulation")
    if "quick" in query_low and "menu" in query_low:
        phrase_candidates.append("quick menu")

    rows: list[tuple[float, int, list[str], str]] = []
    for idx, page in enumerate(pages, start=1):
        text = page.strip("\n")
        if not text.strip():
            continue
        low = text.lower()
        lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
        header = " ".join(lines[:10]).lower()
        score = 0.0
        reasons: list[str] = []

        for phrase in phrase_candidates:
            p = phrase.lower().strip()
            if not p:
                continue
            count = low.count(p)
            if count:
                if p in header:
                    score += 120
                    reasons.append(f"phrase in header: {p}")
                else:
                    score += 35 * min(count, 3)
                    reasons.append(f"phrase: {p}×{count}")

        for term in set(terms):
            count = len(re.findall(rf"\b{re.escape(term)}\b", low))
            if not count:
                continue
            weight = 5 if term in {"camera", "parts", "diagram", "control", "controls", "recipe", "simulation"} else 2
            score += min(count, 8) * weight
            if term in header:
                score += 10
                reasons.append(f"{term} in header")
            elif count >= 2:
                reasons.append(f"{term}×{count}")

        dotted = low.count("........")
        if dotted >= 8:
            score += 45
            reasons.append(f"dotted reference table×{dotted}")

        control_hits = sum(low.count(t) for t in CONTROL_TERMS)
        if control_hits >= 6:
            score += min(control_hits, 30) * 2
            reasons.append(f"control terms×{control_hits}")

        # Downrank boilerplate unless it also looks like a reference table/diagram page.
        if dotted < 8 and any(t in low for t in SAFETY_TERMS):
            score -= 80
            reasons.append("safety/legal downrank")

        if score > 0:
            rows.append((score, idx, reasons[:8], snippet(lines)))

    rows.sort(key=lambda r: r[0], reverse=True)
    return rows


def select_pages(rows: list[tuple[float, int, list[str], str]], total_pages: int, top: int, neighbors: int) -> list[int]:
    selected: set[int] = set()
    for _, page, _, _ in rows[:top]:
        for n in range(page - neighbors, page + neighbors + 1):
            if 1 <= n <= total_pages:
                selected.add(n)
    return sorted(selected)


def render_pages(pdf: Path, pages: list[int], dpi: int) -> Path:
    require_tool("pdftoppm")
    tmp = Path(tempfile.mkdtemp(prefix="manual-pages."))
    # Render pages individually so selected non-contiguous pages stay bounded.
    for page in pages:
        prefix = tmp / f"page-{page:03d}"
        subprocess.run(
            ["pdftoppm", "-png", "-r", str(dpi), "-f", str(page), "-l", str(page), str(pdf), str(prefix)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    return tmp


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", required=True, help="User question or search phrase")
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF, help="Path to PDF manual")
    parser.add_argument("--top", type=int, default=2, help="Number of candidate pages to expand/render")
    parser.add_argument("--neighbors", type=int, default=0, help="Neighbor pages to include around each candidate")
    parser.add_argument("--dpi", type=int, default=150, help="Render DPI for pdftoppm")
    parser.add_argument("--render", action="store_true", help="Render selected pages to temporary PNGs")
    args = parser.parse_args()

    pdf = args.pdf.expanduser().resolve()
    if not pdf.exists():
        print(f"ERROR: PDF not found: {pdf}", file=sys.stderr)
        return 2

    pages = extract_pages(pdf)
    rows = score_pages(pages, args.query)
    if not rows:
        print("No candidate pages found. Try a broader query.")
        return 1

    print(f"PDF: {pdf}")
    print(f"Query: {args.query}")
    print("\nTop candidate PDF leaf pages:")
    for score, page, reasons, snip in rows[: max(args.top, 8)]:
        print(f"\n- PDF leaf {page} | score={score:.1f} | {', '.join(reasons) or 'term hits'}")
        print("  " + snip.replace("\n", "\n  "))

    selected = select_pages(rows, len(pages), args.top, args.neighbors)
    print("\nSuggested pages to visually inspect:", ",".join(map(str, selected)))

    if args.render:
        tmp = render_pages(pdf, selected, args.dpi)
        images = sorted(tmp.glob("*.png"))
        print(f"\nRendered to temp dir: {tmp}")
        print("Read these images with the Read tool before cleanup:")
        for image in images:
            print(f"READ_WITH_TOOL: {image}")
        print(f"\nCleanup after visual inspection:\nrm -rf {tmp}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
