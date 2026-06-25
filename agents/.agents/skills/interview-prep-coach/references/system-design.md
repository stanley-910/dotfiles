# System Design (Databricks, new-grad calibration)

Databricks is a data-infrastructure company. Their system-design prompts skew
**low-level and systems-flavored** — design the primitives that go *into* a data
platform, not consumer products. "Design Twitter / Facebook feed" is the wrong
genre here. New-grad bar = the medium-difficulty infra problems, not staff-level
ones (a Visa network, a hierarchical FS from raw blocks, etc.).

## Problems to practice, in order (build on each other)
1. **Single-node in-memory cache with persistence** — most common; maps to LRU
   Cache (146). Good first problem.
2. **Durable key-value store** — core distributed-systems primitive.
3. **Thread-safe bounded queue** — concurrency; very Databricks-flavored.
4. **Job scheduler with task dependencies** — maps to Course Schedule II (210),
   topological sort.
5. **Distributed file system** — harder; save for late.

Keep from the generic canon: **Rate Limiter** (maps to Hit Counter 362) and a
**URL Shortener** (good capacity-estimation warm-up). Drop Twitter/Facebook feeds.

## Reading foundation
- **DDIA ch 1–3**: reliability/scalability/maintainability, data models, storage
  engines & indexes (B-trees vs LSM trees). Directly answers "why Postgres vs
  Mongo vs Cassandra."
- **DDIA ch 4–5**: encoding/serialization; replication (leader-follower,
  multi-leader, leaderless), replication lag, eventual consistency. Go deep on ch 5.
- **DDIA ch 7 (skim ~pp 220–240)**: ACID *vocabulary* only — atomicity via
  write-ahead logs, durability via fsync, isolation implications. Skip the deep
  isolation-level material.
- **Delta Lake transaction log**: one focused read. It's an append-only JSON commit
  log in `_delta_log/` — atomicity for a data lake. High-signal, almost no
  candidate reads it. (Conceptual cousin of Git's append-only object store.)

## ACID note
Atomicity is genuinely relevant here (Delta Lake's whole pitch is ACID on a lake).
Expect to discuss how writes commit atomically in the durable-KV and DFS problems.
What you can skip is database-internal isolation-level theory.

## What good looks like at this bar
Clarify requirements first; state assumptions; sketch a layered design; justify
each tradeoff (latency vs throughput, sync vs async, SQL vs NoSQL, caching layers)
rather than naming a product; call out failure modes, retries, and monitoring.
Communicate the design — boxes and arrows, thinking aloud.
