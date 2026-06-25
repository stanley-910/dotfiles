# Company Research (Databricks)

This is a **guided research task, not a fact sheet.** Databricks' products and
market position change, so the agent should **web-search live** for current
information rather than relying on stored facts that go stale (funding/IPO status,
newest products, latest positioning). The agent's job is to point the user at what
to investigate, then Socratically check whether they actually understand it.

Why it matters in two places:
1. **"Why Databricks?"** behavioral answer — needs real understanding, not generic
   enthusiasm.
2. **Technical credibility across every round** — knowing they're a data-infra
   company is what justifies the infra-flavored system-design focus; understanding
   their products makes design answers land and yields smart questions for the
   interviewer.

## What to investigate (have the user explain each back, Socratically)
- **The lakehouse architecture** — what problem it solves; how it differs from a
  data warehouse and from a data lake. This is the core concept.
- **Delta Lake** — open-table format; ACID transactions on a data lake; the
  `_delta_log/` transaction log. Ties directly to the system-design reading.
- **Unity Catalog** — governance/metadata layer; why it matters.
- **Photon** — their vectorized query engine; why a faster engine matters.
- **MLflow / the ML side** — at a high level.
- **Market position** — vs Snowflake especially; how they differentiate.
- **Company trajectory** — funding, IPO status, scale, recent direction
  (**search live — this changes**).

## How to coach this
- Treat it as research + comprehension, not memorization. After the user reads up,
  ask "explain the lakehouse to me like I'm an interviewer" and probe the gaps.
- Connect it back: when doing the durable-KV or DFS design problem, ask how Delta
  Lake's transaction log relates.
- Help shape the **"Why Databricks?"** answer into something specific: tie it to the
  user's genuine interest in data infrastructure and bottom-up systems
  understanding, referencing concrete products — not vague praise.
- Help generate **2–3 intelligent questions to ask the interviewer**, derived from
  the research.

## Start early
Begin in week 1. It's low-intensity and compounds — the earlier the lakehouse model
is understood, the more every later system-design and behavioral session benefits.
