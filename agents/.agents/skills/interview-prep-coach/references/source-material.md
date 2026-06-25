# Source Material (map, not the materials themselves)

This file points to study material. Small, distillable reference is **bundled** in
`assets/`. Large or commercially published material (e.g. DDIA) is **referenced by
pointer** — kept on the user's own machine and consulted on demand — rather than
embedded, for both context-weight and copyright reasons.

## Bundled (in `assets/`)
- `network-engineer-roadmap.pdf` — the roadmap.sh network-engineer roadmap. Use it
  only as a map; most of it is network-engineer territory to ignore. The relevant
  slice is distilled in `networking.md`.

## Referenced by pointer (user's local copy / the web)
- **DDIA** (*Designing Data-Intensive Applications*, O'Reilly) — the user's own PDF
  on their machine. Do **not** embed it. When studying a topic, point to the chapter
  (ch 1–3 storage/models, ch 4–5 encoding/replication, ch 7 ACID-vocab skim) and, if
  the user has it open, quiz from the passage they're viewing. Pull from their local
  copy on demand; the skill does not carry the book.
- **Delta Lake transaction log** — official docs (search for the current URL; the
  intro covers `_delta_log/` and the commit model).
- **Boot.dev HTTP trio** — HTTP Protocol, HTTP Servers, HTTP Clients (Go).
- **Cloudflare Learning Center** — one-afternoon articles on DNS, TLS, TCP/IP.
- **PracHub Databricks system-design list** — for the infra-flavored problem set
  (search live; treat individual prompts as practice, calibrate to new-grad bar).

## Why not bundle everything
Skills work best with lean reference and progressive disclosure, not whole books.
Embedding a ~600-page PDF bloats context and is legally murky to redistribute in a
packaged `.skill`. Pointers keep the skill light and the material where it belongs.
