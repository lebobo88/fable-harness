---
name: constitution
description: Show CONSTITUTION.md's content and invariant list on request, re-run the SHA-256 hash check against CONSTITUTION.sha256 on demand, and document the amendment procedure. Useful for Claude to consult proactively as well as for a user to invoke directly.
model: haiku
---

# constitution — inspect, attest, and amend the governance root

This skill is safe and useful for Claude to invoke on its own initiative (e.g. before citing an invariant, or when unsure whether a planned action conflicts with one) — it is not restricted to manual invocation.

## Showing the constitution

On request, read and display `H:\FABLE-HARNESS\CONSTITUTION.md` in full, or just its invariant list (N1 through N11) when the user wants a quick reference rather than the whole document. Always cite invariants in the exact greppable form the constitution itself specifies: `Refused per N<k>: <short reason>`.

## Re-running the hash check (same logic as the SessionStart hook, callable manually)

The `SessionStart` hook computes a SHA-256 hash of `CONSTITUTION.md` and compares it against the checked-in `CONSTITUTION.sha256` sibling file, printing a loud warning banner on mismatch — but per N5, this **never blocks session start** (hooks fail open on what they're not designed to hard-block, and this check is explicitly documented as warn-only, not gating). This skill reruns that identical check on demand:

1. Compute SHA-256 of `H:\FABLE-HARNESS\CONSTITUTION.md`.
2. Compare against the contents of `H:\FABLE-HARNESS\CONSTITUTION.sha256`.
3. Report match/mismatch plainly. On mismatch, do not silently "fix" the hash file — a mismatch means either an unreviewed edit happened (investigate before trusting the current CONSTITUTION.md) or an amendment happened correctly but the hash file wasn't regenerated in the same commit (an N1 process violation to flag, even though the amendment content itself may be fine).

Example command (PowerShell):

```powershell
$actual = (Get-FileHash "H:\FABLE-HARNESS\CONSTITUTION.md" -Algorithm SHA256).Hash
$expected = (Get-Content "H:\FABLE-HARNESS\CONSTITUTION.sha256" -Raw).Trim()
if ($actual -ieq $expected) { "MATCH" } else { "MISMATCH: expected $expected, got $actual" }
```

## Amendment procedure (CONSTITUTION.md N1)

Amending `CONSTITUTION.md` is only ever done via an explicit, reviewed edit — never a silent rewrite by any agent. The full procedure, all in the same commit:

1. Edit `CONSTITUTION.md` with the specific, reviewed change.
2. Regenerate `CONSTITUTION.sha256` from the new file content (e.g. `(Get-FileHash CONSTITUTION.md -Algorithm SHA256).Hash | Out-File CONSTITUTION.sha256`).
3. File a decision record under `memory/decisions/<date>-<slug>.md` documenting context, the decision, alternatives considered, consequences, an owner, and a review date — per the decision-record convention referenced in `AGENTS.md`.
4. Commit all three changes together. Never split the hash regeneration or decision record into a later, separate commit — N1 requires them to land atomically with the edit.

## Constitution citations

`Refused per N1: CONSTITUTION.md may only change via an explicit, reviewed edit that also regenerates CONSTITUTION.sha256 and files a decision record — no agent may silently rewrite it.` Use N5's citation form when reporting hash-check results: this check is warn-only and must never be escalated into a session-start block.
