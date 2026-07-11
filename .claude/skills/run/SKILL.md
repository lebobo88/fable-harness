---
name: run
description: Run a request through the full FABLE-HARNESS lifecycle (triage -> profile -> taxonomy -> generate per section -> judge -> verify -> missability -> finalize). Auto-invocable for substantive feature/bugfix/refactor requests; the actual orchestration logic lives in .claude/workflows/run.js, invoked here via the Workflow tool.
model: sonnet
---

# /run — the FABLE-HARNESS lifecycle driver (thin wrapper)

This skill is a thin wrapper. All real orchestration logic lives in **`.claude/workflows/run.js`** (the actual Claude Code Workflow-tool primitive — do not confuse this with `.claude/team-configs/*.yaml`, which is plain data, not a primitive itself).

## Procedure

1. Mint a `run_id` using the current date/time (e.g. via `Get-Date -Format yyyyMMdd-HHmmss` or the Bash `date` equivalent), suffixed with a short slug from the request. Example: `20260710-183000-add-auth-endpoint`.
2. Create `.fable/<run_id>/` (and its `artifacts/`, `stages/`, `verdicts/` subdirectories) if it doesn't already exist.
3. Write `<run_id>` (no trailing newline) to `.fable/current-run` so the Stop-hook verifier gate (`stop-verify-gate.ps1`) knows which run is active.
4. Invoke the Workflow tool: `Workflow({ name: "run", args: { run_id: "<run_id>", request: "<the user's request text>" } })`.
5. Report the workflow's returned result (`status`, `stageResults`, `missability`) to the user in plain language — don't just dump the raw JSON.
6. On completion (finalized or surfaced), remove `.fable/current-run` (or leave it if the user wants to keep verifying/iterating further — use judgment; if genuinely done, clear it so the Stop hook stops gating on a finished run).

## Constitution citations

Per **N7**, every stage inside `run.js` dispatches a typed agent — never a generic stand-in. Per **N2**, nothing in this pipeline ever touches Fable-5; if the request is unusually high-stakes and the user might benefit from `/plan-deep` instead of (or before) `/run`, say so as a suggestion, never as an automatic substitution.
