---
name: artifact-conventions
description: Reference-only skill documenting where artifacts live, the 3-verdict vocabulary (pass/pass-with-notes/reject), and the Preserved-Invariants-vs-Changed-Behaviors contract for revising an existing artifact. Load before writing or revising any artifact under .fable/. Auto-invocable.
model: haiku
---

# artifact-conventions — where things live and how revisions are contracted

This is a reference-only skill — there is no "action" to invoke beyond loading these conventions into context before an agent writes, archives, or revises an artifact.

## Where artifacts live

Artifacts belong under `.fable/<run_id>/artifacts/<section>-<kind>.md`, where:
- `<run_id>` is the id of the active run (see `.fable/runs.jsonl` for the run ledger).
- `<section>` is the taxonomy section number the artifact belongs to (e.g. `4.13`), as recorded by the `taxonomy-map` skill in `.fable/<run_id>/taxonomy_map.json`.
- `<kind>` names the artifact itself (e.g. `changelog`, `spec`, `adr`, `openapi`).

Example: `.fable/run-2026-07-10-abc123/artifacts/4.7-openapi.md`.

Related per-run state lives alongside artifacts under the same `.fable/<run_id>/` root: `stages/<stage>.json` (verify-loop bookkeeping, see `verify-gate`), `verdicts/<stage>.json`, `telemetry.jsonl`, `handoffs/*.json` (file-mediated cross-session coordination, per `AGENTS.md`).

Curated, committed memory (decisions, invariants ledger, glossary) is a separate, deliberately-written layer at `memory/` in the repo root — distinct from both `.fable/` (gitignored, per-run, ephemeral) and Claude's own automatic auto-memory (`~/.claude/projects/.../memory/MEMORY.md`). See `AGENTS.md`'s "Memory — two layers" section.

## The 3-verdict vocabulary (CONSTITUTION.md N4)

Every judge/verifier/inspector agent emits **exactly one** of:
- `pass` — clean, no notes.
- `pass-with-notes` — acceptable, with recorded caveats that don't block progress.
- `reject` — hard failure; triggers the Reflexion ×1 retry path (see `verify-gate`).

There is never a fourth option and never silence. **If a validation step itself errors or cannot complete, the verdict is `reject`** — a validator that cannot validate has already failed. Never let a tool error or timeout be silently treated as a pass.

## Preserved-Invariants vs Changed-Behaviors (CONSTITUTION.md N9)

Any agent revising an existing artifact (not authoring one fresh) must explicitly produce both lists in its output before making the edit:

- **Preserved Invariants** — behaviors/contracts/decisions from the prior version that remain true and unchanged. Cross-check this list against `memory/invariants.md` if the artifact's domain has entries there.
- **Changed Behaviors** — what is different, and why.

If a proposed change would contradict a previously preserved invariant recorded in `memory/invariants.md`, the agent must **halt, not silently proceed** — surface the conflict to the user or the calling agent rather than resolving it unilaterally.

## Constitution citations

`Refused per N4: validator could not complete — treating as reject, not silence.` / `Refused per N9: proposed change contradicts a preserved invariant in memory/invariants.md — halting rather than proceeding.`
