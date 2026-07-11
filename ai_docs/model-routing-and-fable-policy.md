# Model routing & the Fable-5 manual-only policy (canonical — mirrored by the `model-routing` skill)

This is the single source of truth for how FABLE-HARNESS assigns models. Any agent or skill authored later (including by `meta-agent`) must be grounded in this document, not just the "don't write model: fable" convention alone — that convention is necessary but **not sufficient** on its own (see the six surfaces below).

## Tier table (Opus / Sonnet / Haiku — freely auto-routed)

| Tier | Used for |
|---|---|
| Haiku | Cheap classifiers/routers/triage: `triage`, `profile-loader`, `taxonomy-mapper`, `judge-router`, `missability-inspector`, `docs-author`, `visual-regression-runner`. |
| Sonnet | Default workhorse: most generation/implementation/review agents (`spec-author`, `engineer`, `api-designer`, `data-modeler`, `test-strategist`, `release-planner`, `ops-author`, `ai-controls-author`, `retirement-planner`, `discovery-researcher`, `designer`, `design-system-curator`, `reflexion-coach`, `oracle-evaluator`, `master-plan-patcher`, `run-finalizer`, `agents-md-author`, `governance-author`, `browser-validator`). |
| Opus | Highest-stakes judging/architecture/security/synthesis: `judge-cross-vendor`, `verifier`, `meta-agent`, `strategy-author`, `architect`, `security-reviewer`. |

## Fable-5: never auto-routed — the full enforcement story

**The mistake to never repeat**: treating "never write `model: fable` in agent/skill frontmatter" as sufficient. Claude Code has several independent model-selection surfaces, any one of which could reach Fable-5 if left unaddressed:

1. Subagent frontmatter `model:` field.
2. A per-invocation `model` parameter when dispatching a Task sub-agent.
3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable.
4. The interactive `/model` command.
5. `/advisor` / `advisorModel`.
6. `teammateDefaultModel` (Agent Teams).
7. The project/user `availableModels` setting.

## The policy (addresses every surface above)

1. **`.claude/settings.json` sets `availableModels` to exclude Fable-5** from the pool available to the main interactive session and to all subagent/teammate dispatch. This is the primary structural gate: if Fable isn't in the available set, none of surfaces 1-6 above can silently select it.
2. **No agent file (`.claude/agents/*.md`) ever sets `model: fable`.**
3. **Fable is reachable only through one explicit, manual skill: `/plan-deep`**, gated by `disable-model-invocation: true` (the correct, skill-only field — NOT a subagent field).
4. **The suggestion-and-approval flow lives entirely in the interactive main-loop/skill layer, never inside a `Workflow()` script** (Dynamic Workflows have no mid-run human input beyond permission prompts — a workflow cannot pause mid-pipeline to ask "use Fable?" and resume in the same run). An agent that judges a task Fable-worthy uses `AskUserQuestion` in the normal conversational turn. If the user says yes, the harness writes a short-lived, single-use `.fable/fable-approval.token`, and only then does a **separate, freshly-invoked** `/plan-deep` call proceed with `model: fable`. If the user says no, the token is never written.
5. **A `UserPromptSubmit` hook denies any literal `/model fable` or `/advisor`-to-Fable switch unless `.fable/fable-approval.token` exists and is unconsumed** — closes the direct manual-override surfaces too.
6. This document + the `model-routing` skill are the canonical reference every future agent/skill author (including `meta-agent`) must consult before ever touching the model field.

## Fable-5 prompting quirks (for the one place it IS used — `/plan-deep`)

- No manual extended-thinking budget parameter (`budget_tokens` → 400 error) — adaptive thinking is always on, summarized-only thinking output.
- `effort` is the primary lever: `high` is the recommended default, `xhigh` for the most capability-sensitive workloads.
- Dispatches/sustains parallel subagents more reliably than prior models — prefer async orchestrator↔subagent communication over blocking waits.
- New `reasoning_extraction` refusal category: never instruct it to echo/transcribe/explain its internal reasoning as response text — triggers refusals and elevated fallback to Opus 4.8.
- Has a documented `send_to_user` client-tool pattern for surfacing verbatim progress messages mid-task without ending the turn.

## Sonnet 5 prompting quirks (the default workhorse tier)

- `effort` defaults to `high`; raise to `xhigh` for the hardest coding/agentic tasks.
- New tokenizer produces ~30% more tokens for the same text than Sonnet 4.6 — size `max_tokens` accordingly.
- Follows scope/severity-limiting instructions in review-style prompts more literally than earlier models — for any review/finder agent, **decouple "find everything" from "filter for importance"** into two separate steps (report everything first, filter/rank in a second pass).
- `temperature`/`top_p`/`top_k` at non-default values now return a 400 error — steer tone via system-prompt instructions, not sampling params.
