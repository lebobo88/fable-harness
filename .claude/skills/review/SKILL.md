---
name: review
description: Run one of the 10 standing governance-forum reviews (taxonomy_blueprint.md Section 8.2 — discovery, scope, design, architecture, api_contract, threat_privacy, test_readiness, release_readiness, incident_postmortem, service_review) over an existing artifact or change. Auto-invocable when a user asks for a focused review pass rather than new production. The actual orchestration lives in .claude/workflows/review.js, invoked here via the Workflow tool.
model: sonnet
argument-hint: <forum> <subject>
---

# /review — governance-forum review pipeline (thin wrapper)

This skill is a thin wrapper. All real orchestration logic lives in **`.claude/workflows/review.js`**.

## Procedure

1. Determine which of the 10 forums applies (ask the user if ambiguous — do not guess for a governance action): `discovery`, `scope`, `design`, `architecture`, `api_contract`, `threat_privacy`, `test_readiness`, `release_readiness`, `incident_postmortem`, `service_review`.
2. If there's an active run (`.fable/current-run` exists), use that `run_id`; otherwise mint a fresh one the same way `/run` does, since review artifacts still need a home under `.fable/<run_id>/artifacts/`.
3. Invoke the Workflow tool: `Workflow({ name: "review", args: { forum: "<forum>", run_id: "<run_id>", subject: "<what's being reviewed>" } })`.
4. Report the forum's exit-criteria verdict (per taxonomy_blueprint.md §8.2's "Exit criteria" column) plainly: did this forum's requirements get met, or not, and why.

## Constitution citations

Per **N9**, any reviewer that proposes changes (not just critiques) must state Preserved Invariants vs Changed Behaviors — `review.js` instructs every dispatched reviewer of this explicitly. Per **N7**, reviewers are always typed agents from `FORUM_AGENTS` in `review.js`, never generic dispatch.
