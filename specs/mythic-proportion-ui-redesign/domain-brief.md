# Domain / User-Research Brief — mythic-proportion Web UI Redesign

Confidence: **[H]**igh (evidenced in code/docs) · **[M]**edium (inferred) · **[L]**ow (hypothesis).

## 1. What this product is [H]
A local-first personal "second brain": a drop-folder pipeline turns documents/images into an immutable raw archive plus a self-linking Obsidian-compatible Markdown wiki, indexed by a local SQLite hybrid (BM25 + vector) search layer, layered with a Microsoft-GraphRAG-style knowledge model (entities/relationships/text units/claims/communities) queryable via a 3D graph and multiple retrieval modes — all privacy-by-default (local embeddings, opt-in cloud egress, fail-closed PII redaction, fully-offline mode).

## 2. Who uses it, and in what context [M]
A **solo power-user tool**, not team SaaS: no auth/multi-tenant model exists in the API; the privacy invariants (fail-closed redaction, per-request rehydrate maps, no-cloud-fallback offline mode) exist because the vault holds one person's private notes. User is technical (CLI, drop-folders, Obsidian-comfortable) — closer to a researcher's Obsidian+AI setup than a consumer app. No second persona exists. **Gap**: no interview data — inferred from architecture, not observed usage.

## 3. JTBD per route (Ingest is entry point) [H unless noted]
1. **Ingest** — "When I have a new document, I want it filed + summarized without manual tagging, so I capture knowledge with near-zero friction." Job polling; optional "Build Knowledge Graph" step.
2. **Wiki** — "When I want to review what the system understood, I want to browse pages + wikilinks, so I can verify/correct the compilation."
3. **Graph** — "When I want to see how my knowledge connects, I want to explore the network spatially, so I spot clusters/gaps I'd miss reading linearly." Community clustering is the organizing visual principle at scale.
4. **Search** — "When I remember roughly what I want, I want fast hybrid lookup, so I jump straight to the page."
5. **Ask** — "When I have a question my notes should answer, I want a synthesized, cited answer, so I get an answer instead of re-reading myself." The payoff moment other views exist to keep honest.
6. **Lint** — "When I want to trust my vault's integrity, I want orphans/dangling links/stale entries/thin pages surfaced with a one-click fix, so the brain doesn't rot as it grows." Lower-frequency but high-stakes. **[M]** — no cadence data.
7. **Settings** — "When I want to control cost/privacy/model, I want provider, local/cloud, redaction, and auto-graph toggles in one place, so I control what leaves my machine." Privacy dominates here, not cosmetics.

## 4. Domain vocabulary [H]
**Vault** — root knowledge folder. **Entity** — extracted concept/person/project (distinct from a wiki page). **Relationship** — typed edge between entities. **Text unit** — chunk-level extraction unit (not the whole doc). **Claim** — an extracted, traceable factual statement. **Community** — an entity cluster from Leiden clustering, with a **community report** (LLM summary) — use for graph clusters/hulls, not "group." **Query modes**: `global` (community-summary), `local` (entity-neighbor expansion), `drift` (entity-anchored + community-modulated), `activation` (spreading activation), `auto`/omitted (legacy path). **Collision risk**: retrieval "local" vs. Settings' privacy "Local" — flag for copy pass. **Redaction/rehydration** — PII masking before cloud calls, restored after. **Lint terms**: orphan, dangling link, stale index entry, thin page.

## 5. Emotional register [M/L]
Should read as a **personal instrument for thinking** — not enterprise SaaS (no seat-count nagging, no activity feeds) and not consumer/social (no gamification, no streaks). Closer analogs: Obsidian, a researcher's lab notebook. Existing 3D-graph direction leans "restrained dark theme, desaturated node colors by community, accents reserved for active selection" — a tone signal: quiet, precise, low-chrome, privacy-forward. **[L]** — no sentiment research exists (single known user); treat as hypothesis, not fact.

## Unresolved gaps
No interview data; no usage-frequency data yet (observability layer is future work); "local" vocabulary collision needs a copy decision.
