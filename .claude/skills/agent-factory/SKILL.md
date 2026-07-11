---
name: agent-factory
description: Templates and risk-tier evolution policy for authoring new agents, skills, and hooks — the 3 artifact kinds this harness produces (no "mcp" kind; this harness has no MCP). Used primarily by meta-agent when extending the harness. Auto-invocable.
model: sonnet
---

# agent-factory — templates for the 3 artifact kinds this harness authors

FABLE-HARNESS authors exactly three kinds of artifact: **agent**, **skill**, **hook**. (Sibling-repo research references a fourth "mcp" kind — not applicable here; CONSTITUTION.md N8 means this harness never registers an MCP server, so there is no mcp-config artifact kind to template.)

## Frontmatter templates

### Agent (`.claude/agents/<name>.md`)

```yaml
---
name: <lowercase-hyphen-name>
description: <dense description including trigger conditions — this drives delegation>
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet   # or haiku / opus per model-routing skill's tier table — NEVER fable
---
```

Required: `name`, `description`. `tools:` should be an explicit allowlist built from Read/Write/Edit/Glob/Grep/Bash + Task dispatch only — no MCP tool names anywhere (N8). Consult the `model-routing` skill's tier table before picking `model:`.

### Skill (`.claude/skills/<name>/SKILL.md`)

```yaml
---
name: <name>
description: <dense description — drives auto-invocation unless disable-model-invocation is set>
model: sonnet   # optional; omit to inherit, or haiku/opus/sonnet per tier table
# disable-model-invocation: true   # only for plan-deep and install-user-scope — manual-only skills
---
```

Required: `name`, `description`. Add `disable-model-invocation: true` only when the skill must be unreachable by Claude's own judgment (currently: `plan-deep`, `install-user-scope`). `context: fork`, `allowed-tools`, `argument-hint` are optional per the skills reference.

### Hook (entry inside `.claude/settings.json` `hooks.<EventName>[]`, plus the script it points at under `.claude/hooks/`)

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "pwsh -File .claude/hooks/pretooluse-bash-safety.ps1" }
  ]
}
```

Hook scripts must: fail open on internal error (`exit 0` on unexpected parse/exception — N5), fail closed on a genuine policy violation (`exit 2`, never `exit 1` — N5's explicit gotcha callout), and — if enforcing a whitelist (e.g. the Bash safety gate) — normalize input (strip quotes, collapse whitespace, split on `&&`/`|`/`;`) before matching each subcommand independently against an explicit allow-set (N6).

## Risk_class → evolution_policy table

| risk_class | evolution_policy |
|---|---|
| low | Auto-commit the new artifact once it passes schema/invariant validation — no human gate required. |
| medium | Require a human review before the artifact is considered final; may be drafted and staged, but not promoted, without sign-off. |
| high | Require a human review before final; treat any ambiguity as a reason to escalate rather than assume. |
| critical | Require a human review before final, and prefer pairing it with an explicit decision record under `memory/decisions/` regardless of outcome. |

meta-agent (or any authoring agent) must classify every new artifact's risk_class before deciding whether it can auto-commit. When in doubt, round up to the more conservative tier — this mirrors the evolution-handoff propose/evaluate/commit/HITL contract pattern from sibling-repo research, reimplemented here without any MCP/TheEights dependency (N8): "auto-commit" and "require human review" are just local git-commit-or-don't decisions, not calls to an external evolution service.

## The hard rule

**No agent file ever sets `model: fable`.** This is non-negotiable and is CONSTITUTION.md N2. If `meta-agent` or any other authoring flow is about to write `model: fable` into anything other than `.claude/skills/plan-deep/SKILL.md`, it must stop and cite `Refused per N2: no agent file may ever set model: fable.` See the `model-routing` skill for the full six-surface reasoning behind why this rule exists.

## Constitution citations

N2 (Fable manual-only — the hard rule above), N7 (typed-agent provenance — never scaffold a "general-purpose" stand-in when a typed producer is what's needed), N8 (no MCP — hook/agent tool allowlists never include `mcp__*` names).
