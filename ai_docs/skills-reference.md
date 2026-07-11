# Skills reference (offline grounding — verified against code.claude.com/docs/en/skills)

Skills are folders: `.claude/skills/<name>/SKILL.md` (project) or `~/.claude/skills/<name>/SKILL.md` (user).

## Frontmatter fields

- `name`, `description` — description drives auto-invocation (Claude decides when it's relevant); only name+description load into context at session start by default (low cost), full body loads only when invoked.
- `disable-model-invocation: true` — hides the skill from Claude entirely; reachable ONLY via manual `/skill-name` invocation by the user. Reduces context cost to zero (even the description doesn't load). **This is the ONLY mechanism FABLE-HARNESS uses to gate Fable-5 access — via the `plan-deep` skill. This field is skill-only; it does NOT exist on subagent frontmatter (a mistake corrected during planning — do not try to make an agent "manual-only" this way).**
- `user-invocable: false` — inverse-ish: hides the skill from the user's slash-menu (Claude-only). **Caution: this only changes menu visibility, it does NOT block programmatic Skill-tool access — never rely on this as a security boundary.**
- `context: fork` — runs the skill body in an isolated subagent context.
- `allowed-tools` — pre-approves specific tools for this skill's execution.
- `argument-hint`, `model` — as usual.

## Skills vs. commands

`.claude/commands/*.md` files still work and create the same slash command as an equivalent skill — commands were merged into skills, not deleted or broken. FABLE-HARNESS simply chooses to author everything as skills going forward for consistency (one format, not two), not because commands are deprecated/broken.

## Dynamic context injection

`` !`command` `` syntax inside a skill body runs a shell command and injects its live output into context when the skill runs.

## FABLE-HARNESS's skill roster (11 total — see plan.md for full descriptions)

`plan-deep` (the only skill with `model: fable`, `disable-model-invocation: true`), `plan`, `model-routing`, `taxonomy-map`, `verify-gate`, `artifact-conventions`, `run` (thin wrapper around `.claude/workflows/run.js`), `review` (thin wrapper around `.claude/workflows/review.js`), `agent-factory`, `constitution`, `install-user-scope` (manual-only, never auto-invoked).
