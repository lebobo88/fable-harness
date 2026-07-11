# CLAUDE.md — Claude-specific import shim

@AGENTS.md

The full project contract lives in `AGENTS.md` (propagates to this file automatically — do not duplicate content here, this file only adds Claude-Code-specific routing notes).

@memory/invariants.md
@ai_docs/model-routing-and-fable-policy.md

## Session-start routing table (quick reference — see AGENTS.md and ai_docs/ for full detail)

| Task shape | Route to |
|---|---|
| Everyday planning | `/plan` (Sonnet) |
| Exceptionally deep/high-stakes planning | `/plan-deep` (manual only — will ask before ever touching Fable-5) |
| Full request lifecycle (triage → generate → judge → verify → finalize) | `/run` |
| Governance-forum style review | `/review` |
| Show/attest the constitution | `/constitution` |
| Install this harness at user scope (all projects) | `/install-user-scope` (manual only, merge-safe) |

## The one rule that matters most

**Fable-5 is never auto-routed.** If you ever find yourself about to write `model: fable` anywhere outside `.claude/skills/plan-deep/SKILL.md`, stop — that's a constitution violation (N2). Ask the user first via `AskUserQuestion`, wait for an explicit yes, and only then let a fresh `/plan-deep` call proceed.

## Memory note

This project has two memory layers. Claude's own auto-memory (this file's directory-adjacent `memory/MEMORY.md` under `~/.claude/projects/...`) is automatic and low-signal — leave it on, don't fight it. The **`memory/` directory in this repo** is our curated, committed, high-signal record (decisions, invariants, glossary) — that's the one that's authoritative when the two disagree.
