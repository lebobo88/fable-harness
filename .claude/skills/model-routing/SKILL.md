---
name: model-routing
description: Canonical model-tier reference and the Fable-5 manual-only enforcement protocol. Consult before writing or changing any model field (agent frontmatter, skill frontmatter, Task dispatch parameter, settings.json availableModels, env vars). Auto-invocable — any agent or skill authoring a new artifact should load this first.
model: haiku
---

# model-routing — consult before touching any model field

This skill is a pointer to the single source of truth, `ai_docs/model-routing-and-fable-policy.md` — it summarizes rather than duplicates that document at length. If anything here and that file conflict, the `ai_docs` file wins; re-read it directly for the full text.

**If you are about to write `model: fable` anywhere except `.claude/skills/plan-deep/SKILL.md`, STOP — that is a CONSTITUTION.md N2 violation.** No exceptions, no "just for this one special agent."

## Tier table (Opus / Sonnet / Haiku — freely auto-routed)

| Tier | Used for |
|---|---|
| Haiku | Cheap classifiers/routers/triage — `triage`, `profile-loader`, `taxonomy-mapper`, `judge-router`, `missability-inspector`, `visual-regression-runner`. |
| Sonnet | Default workhorse — most generation/implementation/review agents (`spec-author`, `engineer`, `api-designer`, `data-modeler`, `test-strategist`, `release-planner`, `ops-author`, `ai-controls-author`, `retirement-planner`, `discovery-researcher`, `designer`, `design-system-curator`, `reflexion-coach`, `oracle-evaluator`, `master-plan-patcher`, `run-finalizer`, `agents-md-author`, `governance-author`, `browser-validator`, `docs-author`). |
| Opus | Highest-stakes judging/architecture/security/synthesis — `judge-cross-vendor`, `verifier`, `meta-agent`, `strategy-author`, `architect`, `security-reviewer`. |
| Fable | **Never auto-routed.** Reachable only through `/plan-deep` (`disable-model-invocation: true`), and only after either (a) direct user invocation of that command, or (b) an agent-suggested path that has gone through the `AskUserQuestion`-then-token flow below. |

## The six surfaces Fable-5 could leak through (why frontmatter discipline alone is not enough)

1. Subagent frontmatter `model:` field.
2. A per-invocation `model` parameter when dispatching a Task sub-agent.
3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable.
4. The interactive `/model` command.
5. `/advisor` / `advisorModel`.
6. `teammateDefaultModel` (Agent Teams).
7. (Structural, addresses all of the above) the project/user `availableModels` setting in `.claude/settings.json`.

## The full enforcement protocol

1. `.claude/settings.json` sets `availableModels` to exclude Fable-5 from the pool available to the main interactive session and to all subagent/teammate dispatch. This is the primary structural gate — if Fable isn't in the available set, none of surfaces 1-6 can silently select it.
2. No agent file (`.claude/agents/*.md`) ever sets `model: fable`.
3. Fable is reachable only through `/plan-deep`, gated by `disable-model-invocation: true`.
4. The suggestion-and-approval flow lives entirely in the interactive main-loop/skill layer, never inside a `Workflow()` script (workflows have no mid-run human input). An agent that judges a task Fable-worthy uses `AskUserQuestion` in the normal conversational turn. If the user says yes, the harness writes a single-use `.fable/fable-approval.token`; only then does a **separate, freshly-invoked** `/plan-deep` call proceed with Fable. If the user says no, the token is never written.
5. A `UserPromptSubmit` hook denies any literal `/model fable` or `/advisor`-to-Fable switch unless `.fable/fable-approval.token` exists and is unconsumed.
6. This document + `ai_docs/model-routing-and-fable-policy.md` are the canonical reference every future agent/skill author (including `meta-agent`) must consult before ever touching the model field.

## Constitution citation

Cite `N2` when refusing any attempt to write `model: fable` outside `plan-deep`, or when denying an unapproved `/model`/`/advisor` switch to Fable: `Refused per N2: Fable-5 is manual-only, never auto-routed.`
