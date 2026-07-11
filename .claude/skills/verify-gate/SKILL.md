---
name: verify-gate
description: Dispatches the independent verifier agent, enforces Reflexion x1 (one retry-with-critique per stage) and bounded-retry-then-escalate at 3 total verify loops. This is what /verify invokes and what the Stop hook ultimately points at. Auto-invocable.
model: sonnet
---

# verify-gate — independent verification with bounded retry

This skill is the operational home of CONSTITUTION.md N3 (Reflexion ×1, bounded retry-then-escalate) and N4 (fail-closed, three verdicts only). It dispatches the `verifier` agent — never a generic/untyped stand-in (N7) — and manages the retry-counter bookkeeping that N3 depends on.

## Procedure

1. **Read the stage state.** Load `.fable/<run_id>/stages/<stage>.json`. If it doesn't exist yet, create it with `{"stage": "<stage>", "verify_loops": 0, "reflexion_used": false, "last_verdict": null, "history": []}`.
2. **Dispatch `verifier`** via Task (typed agent, N7) — never let a general-purpose Task stand in. The verifier runs with no shared context with the builder, re-derives claims from disk rather than trusting self-report, and returns exactly one of `pass`, `pass-with-notes`, `reject` (N4). If the verifier itself errors or cannot complete, treat that as `reject` — "a validator that cannot validate has already failed."
3. **On `pass` or `pass-with-notes`:** record the verdict in `stages/<stage>.json`, append to `history`, and stop — the stage clears.
4. **On `reject`:**
   a. Increment `verify_loops` in `stages/<stage>.json`.
   b. If `verify_loops` has now reached **3 total verify loops**, do not retry again — **escalate to the human** instead of looping. Report the verifier's `reject` reasons and the full retry history, and wait for explicit human direction. Do not silently re-attempt a 4th time under any circumstance.
   c. If `verify_loops` is still under 3 and `reflexion_used` is `false`: this is the single Reflexion retry (N3 — **at most one** retry-with-critique per stage). Set `reflexion_used: true`, bundle the verifier's critique with the original generator prompt (this is what `reflexion-coach` does — dispatch it rather than hand-rolling the retry prompt here), re-run the stage's producer, then loop back to step 2.
   d. If `reflexion_used` is already `true` and a further loop is needed before hitting the loop-3 ceiling: this can happen when a stage is re-entered later (e.g. after the human resolves an earlier escalation) — still count toward the 3-loop ceiling; do not reset `reflexion_used` to allow indefinite additional reflexion retries. Reflexion ×1 means one critique-guided retry per stage, full stop; the loop-3 ceiling is a separate, additional cap on total verify attempts.

## Relationship to the Stop hook

The `Stop` hook (wired in a later phase, per `plan.md`'s build sequence) points at this skill via a `/verify` invocation. It must guard with `stop_hook_active` to avoid recursive triggering, and it inherits this skill's same 3-loop escalation ceiling rather than defining its own — do not let the hook and this skill drift out of sync on what "3 loops" means.

## Constitution citations

`Refused per N3: Reflexion ×1 already used for this stage — additional failures escalate to human, not silent retry.` / `Refused per N4: verifier returned reject (or could not complete) — treating as hard stage failure.`
