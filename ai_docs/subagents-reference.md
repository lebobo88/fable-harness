# Subagents reference (offline grounding — verified against code.claude.com/docs/en/sub-agents)

Subagents are Markdown files with YAML frontmatter in `.claude/agents/` (project scope) or `~/.claude/agents/` (user scope).

## Frontmatter fields

- `name` (required) — lowercase, hyphenated identifier.
- `description` (required) — drives the delegation trigger; Claude decides when to dispatch this agent based on this text, so it must be dense and specific about *when* to use it.
- `tools` (optional) — an allowlist. This is the delegation-contract mechanism: an agent can only use what's listed here (plus whatever's implied by `skills:`).
- `skills` (optional) — preload specific skills' full content into this agent's context at spawn.
- `model` (optional) — accepted values: `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit`. **`fable` is an officially supported value — this is exactly the lever FABLE-HARNESS's Fable-manual-only policy has to control. See model-routing-and-fable-policy.md. No agent file in this harness ever sets `model: fable`.**

## What a subagent sees at spawn (fresh, isolated context)

- Its own system prompt (NOT the full Claude Code system prompt).
- Full content of any skills listed in its `skills:` field.
- CLAUDE.md and git status — **except the built-in Explore and Plan agents, which omit both**.
- Whatever context the calling agent/session passes in the dispatch prompt.

## What subagents do NOT do

Plain subagents are **strictly hierarchical, one-shot**: dispatch → isolated work in a fresh context window → a single summary returned to the caller. They do **not** coordinate with each other, do not share a task list, and are not "a lead assigning subtasks to peers who report back live." That richer coordination behavior is a separate, distinct, experimental, opt-in feature — Agent Teams (see below) — not a property of ordinary subagents.

## Resolution priority (when the same name exists at multiple scopes)

Subagents: managed > CLI flag > project > user > plugin.
(Skills use a different order: managed > user > project. Hooks don't override at all — they merge and all fire.)

## Cost-control guidance (official)

Route cheap/routine subagent tasks to Haiku. This harness's model-tier table (see model-routing skill): Haiku for classifiers/routers/triage, Sonnet as the default workhorse, Opus for highest-stakes judging/architecture/security/synthesis. Fable is never in this rotation.

## Agent Teams (experimental, opt-in — a distinct feature from plain subagents)

Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json `env` or shell environment. One lead + teammates *within a single session*, coordinating via a shared task list (not a central orchestrator like plain subagents). Storage: `~/.claude/teams/{team-name}/config.json` (removed at session end), `~/.claude/tasks/{team-name}/` (persists). `team-name` = `session-` + first 8 chars of session ID.

Teammates can be spawned from subagent definitions — honors that definition's `tools` allowlist and `model`; the definition body is appended to (not replacing) the teammate's system prompt. **`skills:` and `mcpServers:` frontmatter fields are NOT applied when a subagent definition runs as a teammate** — teammates load skills/MCP from project+user settings instead, same as a regular session.

Three dedicated hooks for team quality gates: `TeammateIdle`, `TaskCreated`, `TaskCompleted` — each exitable with code 2 to block/require-more-work + send feedback.

**Hard limitations (confirmed, do not assume otherwise)**: one team per session, no nested teams, a teammate cannot become a lead, no *background* subagents may be spawned from an in-process teammate (foreground/synchronous Task-tool dispatch during a teammate's own turn is still fine — that's just ordinary subagent delegation, not nested teaming). No native session-to-session messaging exists — cross-session "team lead to team lead" coordination in FABLE-HARNESS is achieved via file-based handoff envelopes under `.fable/<run_id>/handoffs/*.json`, not a real message bus. Cost/latency reality: ~3-4x token cost vs. a sequential session, 20-30s teammate startup latency; practical team size is 2-5 agents. **Use sparingly** — default to `.claude/workflows/*.js` (Workflow-tool pipeline/parallel) for fan-out that doesn't need live peer coordination.
