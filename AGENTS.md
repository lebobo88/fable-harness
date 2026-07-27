# AGENTS.md — FABLE-HARNESS cross-tool behavioral contract

This document is the project layout and workflow-rules reference for any AI agent working in this repository (Claude Code, or any other tool that reads `AGENTS.md`). `CLAUDE.md` is a thin, Claude-specific import shim over this file.

## What this project is

FABLE-HARNESS is an all-in-one software-development platform built entirely from Claude Code's native interactive-CLI primitives — agents, skills, hooks, memory files, the Workflow tool, git worktrees, plan mode. It has **no MCP servers** and never runs in `-p`/headless mode (see `CONSTITUTION.md` N8). Organized around the 16-section SDLC taxonomy in `taxonomy_blueprint.md`.

## Directory layout

```
CONSTITUTION.md / CONSTITUTION.sha256   governance root + integrity hash (see N1)
AGENTS.md, CLAUDE.md                    this file / the Claude-specific shim
plan.md                                 the build plan (see also C:\Users\robob\.claude\plans\)
taxonomy_blueprint.md                   the 16-section SDLC taxonomy content is organized around
.claude/
  agents/          32 subagent .md files — one taxonomy-domain producer or governance role each
  skills/          11 skill folders (SKILL.md each) — the user-facing / auto-invocable surface
  skills/lib/      shared assets READ BY skills (mirrors hooks/lib/ below) — not a Claude Code
                   primitive itself: plan-template.html / plan-template-lite.html (planf3 HTML
                   plan skeleton + embedded CSS) and plan-images.ps1 (+.sh mirror), a local,
                   no-network CLI that extracts/applies a plan's {{...IMAGE:}} figure slots
  workflows/       *.js Workflow-tool scripts — the REAL reusable-orchestration primitive
                   (run.js, review.js). Do not confuse with team-configs/, which is just data.
  hooks/ (+lib/)   hook scripts (.ps1 primary, .sh mirror), all fail-open (N5)
  team-configs/    plain YAML data (stage lists, rubric refs) READ BY workflows/*.js scripts —
                   not a Claude Code primitive itself
  rubrics/         judge rubrics (rfc-2119, c4, openapi, owasp-asvs, wcag, ...)
  profiles/        project-archetype profiles (web-ui, api, cli, ai-agentic, ...)
  settings.json    hooks + permissions + availableModels (the primary Fable gate, see N2)
ai_docs/           offline grounding copies of Claude Code mechanics (hooks/subagents/skills
                   reference, the model-routing-and-fable-policy, prompting quirks) — read these
                   before authoring any new agent/skill so you don't have to re-derive them
memory/            OUR curated, committed memory (decisions/, invariants.md, glossary.md,
                   index.jsonl) — distinct from Claude's own automatic auto-memory, see below
specs/             top-level plan output from `plan`/`plan-deep` when no run is active — a
                   self-contained <slug>.html (planf3 style) plus a sibling <slug>/ folder of
                   plan-diagram PNGs; when a run IS active, plans land under
                   .fable/<run_id>/artifacts/ instead (see below)
.fable/            gitignored per-run state (replaces what an MCP-backed SQLite ledger would do
                   in the sibling repos this harness was designed from) — run.json,
                   taxonomy_map.json, stages/, verdicts/, artifacts/, telemetry.jsonl, and the
                   single-use fable-approval.token
```

## Multi-agent systems — use honestly, per what Claude Code actually supports

1. **Hierarchical Task sub-agents** are the default fan-out mechanism, used via `.claude/workflows/*.js` pipeline/parallel calls. Always dispatch a **typed** producer agent (e.g. `engineer`, `security-reviewer`) — never a generic/untyped stand-in (N7).
2. **Agent Teams** (experimental, opt-in) may be used for genuinely live, actively-communicating parallel work within one session, but never assume a teammate can become a lead or spawn a nested team — it can't. Default to plain sub-agents / Workflow-tool fan-out otherwise; it's cheaper and non-experimental.
3. **Cross-session "team lead to team lead" coordination** has no native Claude Code primitive. When the harness needs it (e.g. multiple `claude --worktree` sessions each running their own Agent Team), coordination is **file-mediated**: sessions read/write shared handoff envelopes under `.fable/<run_id>/handoffs/*.json`. Never assume a message actually crosses sessions in real time — it's async, disk-based coordination, not a message bus.

## Memory — two layers, know the difference

- **Auto-memory** (`~/.claude/projects/<project>/memory/MEMORY.md`): Claude's own built-in, automatic layer. It decides what to remember; low-signal but free. Left on.
- **Curated memory** (`memory/` in this repo, committed): high-signal, written deliberately by agents via `artifact-conventions`. Decision records, the invariants ledger, the glossary. This is authoritative; auto-memory is convenience.

## Cross-vendor judging

`judge-cross-vendor` shells out to `codex exec --sandbox read-only --skip-git-repo-check "<prompt>"` (OpenAI Codex CLI, confirmed installed) as a genuine equal-weight second opinion, normalizing its verdict into the same `pass`/`pass-with-notes`/`reject` vocabulary used everywhere else (N4). See `.claude/agents/judge-cross-vendor.md` for the exact contract.

## Engineering standards

- Build on `skills/`, not `commands/` (both still work; we standardize on skills for consistency).
- Every producer agent's `tools:` allowlist is Read/Write/Edit/Glob/Grep/Bash + Task dispatch only. The **single** permitted MCP namespace anywhere in this repo is `mcp__claude-in-chrome__*`, and only for observing a locally-served page (screenshots, console/network reads, JS evaluation, frame-time sampling) — see N8's narrow exception and `memory/decisions/2026-07-26-n8-chrome-mcp-exception.md`. It must stay non-load-bearing: detect its absence and degrade to an explicit `unverified` report. No other MCP namespace may appear in any agent allowlist, and this repo still registers no MCP server of its own.
- Reflexion ×1, bounded-retry-then-escalate at 3 loops (N3) — never loop forever on a failing verification.
- When revising an existing artifact: state Preserved Invariants vs Changed Behaviors explicitly (N9).
