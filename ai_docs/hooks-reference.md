# Hooks reference (offline grounding — verified against code.claude.com/docs/en/hooks)

Claude Code hooks fire at lifecycle events. There are roughly 30 distinct event names; only 7 fit cleanly into a simple "three cadences" framing (once per session: `SessionStart`, `SessionEnd`; once per turn: `UserPromptSubmit`, `Stop`, `StopFailure`; per tool call: `PreToolUse`, `PostToolUse`). The rest (`Setup`, `PermissionRequest`, `PermissionDenied`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `MessageDisplay`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`) are their own thing — don't force them into that framing.

## Config schema

Top-level `hooks` key in `settings.json`:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName|OtherTool",
        "hooks": [
          { "type": "command", "command": "...", "timeout": 10 }
        ]
      }
    ]
  }
}
```

`matcher` is an exact string, a pipe/comma-separated list (when it only contains `[a-zA-Z0-9_\-, |]`), or an unanchored JS regex otherwise (e.g. `mcp__memory__.*`).

## Handler types (`type` field, required)

- `command` — shell script, event JSON on stdin. Fields: `command`, `args`, `shell`, `timeout`.
- `http` — POST to a URL. Fields: `url`, `headers`, `allowedEnvVars`. Needs a 2xx response + JSON to block; non-2xx is always non-blocking.
- `mcp_tool` — calls a connected MCP server tool. **Not usable in FABLE-HARNESS (no MCP).**
- `prompt` — single-turn cheap model as a policy/quality judge. Fields: `model`, `prompt`. This is the mechanism behind our PreToolUse Edit|Write quality gate.
- `agent` — experimental, spawns a subagent with Read/Grep/Glob access for the check.

## Exit-code contract (the most common gotcha)

- **0** = success; stdout parsed as JSON.
- **2** = blocking error; stderr fed back to Claude; **any JSON on stdout is IGNORED on exit 2** (only stderr matters).
- **1 is explicitly NOT blocking** despite being the conventional Unix failure code. If a hook is meant to enforce policy, it MUST exit 2, not 1.
- Any other non-zero = non-blocking, stderr shown to user, execution continues.
- Exception: `WorktreeCreate` aborts on ANY non-zero exit, not just 2.

## JSON output control

Common fields: `continue` (bool), `stopReason`, `suppressOutput`.

`PreToolUse` supports `hookSpecificOutput`:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "...",
    "updatedInput": { "command": "modified command" },
    "additionalContext": "..."
  }
}
```

`PostToolUse` supports `{"decision": "block", "reason": "..."}` — can't undo the already-run tool call, just feeds Claude a correction.

## Stop hook as a deterministic gate

Blocks turn-ending until a check passes — but Claude Code force-overrides after **8 consecutive blocks** to prevent a truly infinite loop. Always guard with `stop_hook_active` (present in the stdin JSON) before re-blocking, to avoid unnecessary recursion before that ceiling.

## Config scopes (highest → lowest precedence)

Managed policy (enterprise, e.g. `C:\Program Files\ClaudeCode\managed-settings.json`) > `.claude/settings.json` (project, shared) > `.claude/settings.local.json` (project, personal, gitignored) > `~/.claude/settings.json` (user, all projects) — plus plugin `hooks.json`. **All matching hooks across scopes merge and fire — hooks do NOT override by name like skills/subagents do.**

## Permission rules (same file, separate from hooks)

`permissions.allow` / `permissions.deny` — deny always wins (checked first), then ask, then allow (unlisted = ask). Pattern syntax: `Bash(npm run *)`, `Read(./.env*)`, `WebFetch(domain:example.com)`.

**Gotcha**: `Bash(ls *)` (space before `*`) does NOT match `lsof`; `Bash(ls*)` (no space) matches both. Compound shell commands are split on shell operators (`&&`, `|`, `;`) and each subcommand must independently match a rule. Even in `bypassPermissions` mode, `.git`, `.claude`, `.vscode` stay write-protected (with carve-outs for `.claude/commands|agents|skills`).

## FABLE-HARNESS's own hook wiring (see CONSTITUTION.md and settings.json)

Batch 1 (no dependencies): `SessionStart` (constitution hash-attest, warn-only), `PreToolUse/Bash` (whitelist L4 safety), `PreToolUse/Edit|Write` (prompt-type quality gate), `UserPromptSubmit` (Fable-approval-token gate).
Batch 2 (after verifier exists): `Stop` (verifier gate, `stop_hook_active`-guarded, 3-loop escalation ceiling).
All hooks fail open on internal script errors (`try{...}catch{exit 0}`) — a hook bug must never block the session.
