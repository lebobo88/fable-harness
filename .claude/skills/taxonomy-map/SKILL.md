---
name: taxonomy-map
description: Maps a request to one or more of the 16 taxonomy_blueprint.md sections (4.1-4.16), enforcing the taxonomy-mapping-with-floor rule — even trivial requests get a floor artifact. Delegates the actual mapping decision to the taxonomy-mapper agent and persists the result to .fable/<run_id>/taxonomy_map.json. Auto-invocable.
model: haiku
---

# taxonomy-map — taxonomy-mapping-with-floor

Every request this harness handles maps to **at least one** of the 16 sections of `taxonomy_blueprint.md` (§4.1 Strategy through §4.16 Retirement). This skill's job is to make that mapping explicit and durable, and to guarantee a floor artifact even for trivial requests — no request is handled with zero recorded taxonomy footprint.

## What this skill does

1. **Delegates the mapping decision itself** to the `taxonomy-mapper` agent via Task — do not hand-roll the mapping logic in this skill's own body. Dispatch it as a typed producer agent (CONSTITUTION.md N7 — never substitute a generic/untyped agent for this).
2. Passes the agent the request text plus (if available) the `triage` classification (trivial/standard/major).
3. Reads back the agent's mapping: a list of taxonomy sections (by number, e.g. `4.13`) plus the artifact stub(s) each requires.
4. **Enforces the floor**: if the mapping would otherwise come back empty (e.g. a genuinely trivial request), it must still resolve to at least one section — typically §4.13 (Documentation) with a changelog-entry artifact as the minimum floor artifact. Never let a request pass through with zero mapped sections.
5. Writes the result to `.fable/<run_id>/taxonomy_map.json` with this shape:

```json
{
  "run_id": "<run_id>",
  "request_summary": "<short description>",
  "sections": ["4.13"],
  "floor_applied": true,
  "artifacts_required": ["changelog entry"],
  "mapped_at": "<ISO timestamp>"
}
```

6. If a `.fable/<run_id>/taxonomy_map.json` already exists for this run, read and reuse it rather than re-mapping from scratch — the mapping is a one-time-per-run decision, not something to redo on every stage.

## Section reference

See `taxonomy_blueprint.md` §3 ("Taxonomy at a glance") for the full list of all 16 sections and §4 for their detailed contents. Do not duplicate that list here — read the file directly when the specific section boundaries matter.

## Constitution citation

This skill upholds the taxonomy-mapping-with-floor governance pattern referenced in `plan.md`'s roster and indirectly supports N7 (typed-agent provenance) by always dispatching the real `taxonomy-mapper` agent rather than inlining the decision.
