# FABLE-HARNESS Constitution

This document is the immutable governance root for FABLE-HARNESS. Every agent, skill, and hook cites these invariants by ID (`N1`..`N11`) when it refuses an action or gates a decision. Lower invariant numbers win on conflict, except **N2 (Fable manual-only) and N4 (fail-closed validation) always win over everything except N1 itself.**

Integrity: this file's SHA-256 hash is checked at every `SessionStart` against `CONSTITUTION.sha256` (sibling file). A mismatch prints a loud warning banner — it never blocks session start (hooks fail open per N5). Amending this file requires regenerating `CONSTITUTION.sha256` in the same commit and recording the change in `memory/decisions/`.

## Invariants

**N1 — Constitution integrity.** This file is the single source of truth for governance. It changes only via an explicit, reviewed edit that also regenerates `CONSTITUTION.sha256` and files a decision record. No agent may silently rewrite it.

**N2 — Fable-5 is manual-only, never auto-routed.** No agent file (`.claude/agents/*.md`) may ever set `model: fable`. The only Fable-capable entrypoint in the entire harness is the `/plan-deep` skill, gated by `disable-model-invocation: true`. Any agent that judges a task "Fable-worthy" must ask the user directly via `AskUserQuestion` in the normal conversational turn — never inside a `Workflow()` script, which has no mid-run human input. Only an explicit "yes" writes a single-use `.fable/fable-approval.token`; only then may a fresh `/plan-deep` invocation proceed with Fable. See `ai_docs/model-routing-and-fable-policy.md` for the full six-surface enforcement story (this is not just a frontmatter convention — `availableModels`, `CLAUDE_CODE_SUBAGENT_MODEL`, `/model`, `/advisor`, and `teammateDefaultModel` are all separately gated).

**N3 — Reflexion ×1 and bounded retry-then-escalate.** Any stage that fails verification gets at most one retry-with-critique (Reflexion ×1), tracked in `.fable/<run_id>/stages/<stage>.json`. The independent `verifier` agent's Stop-hook gate is capped at 3 verify loops; on the 4th failure it escalates to the human rather than looping forever.

**N4 — Fail-closed validation, three verdicts only.** Every judge/verifier/inspector agent emits exactly one of `pass`, `pass-with-notes`, `reject` — never a fourth option, never silence. If a validation step itself errors or cannot complete, the verdict is `reject`: a validator that cannot validate has already failed.

**N5 — Hooks fail open on internal error, fail closed on policy violation.** A bug inside a hook script (parse error, unexpected exception) must `exit 0` and never block the session — a broken hook must not brick the harness. A genuine policy violation the hook is designed to catch (a non-whitelisted Bash command, an unapproved Fable switch) must `exit 2`, never `exit 1` (exit 1 is non-blocking in Claude Code and is a common accidental-bypass gotcha).

**N6 — Whitelist-first shell safety (L4).** The `PreToolUse/Bash` hook is a whitelist, not a blacklist: commands are normalized (quotes stripped, whitespace collapsed) and split on shell operators (`&&`, `|`, `;`) before each subcommand is checked independently against an explicit allow-set. Anything not on the allow-set is denied by default. Prompt-level "don't run dangerous commands" instructions are treated as advisory only, never as the actual security boundary.

**N7 — Typed-agent provenance.** Never substitute a generic/untyped agent dispatch for a typed producer agent (e.g. never let a general-purpose Task stand in for `engineer` or `security-reviewer`) — doing so breaks audit/replay provenance in `.fable/<run_id>/`.

**N8 — No MCP servers, no headless; one narrow read-only consumer exception.** FABLE-HARNESS runs only through interactive Claude Code CLI sessions (`claude`, `claude --worktree`, `claude --resume`, etc.). It never registers an MCP server of its own and never depends on `-p`/print/headless invocation as part of its own operation. Local CLI tools and hook scripts are fine, since they're only ever invoked from within an interactive session.

**Narrow exception (added 2026-07-26):** agents MAY list `mcp__claude-in-chrome__*` tools in their allowlist for the sole purpose of *observing a locally-served page* — screenshots, console and network reads, JS evaluation, frame-time sampling. This registers no server: the browser MCP is provided by the operator's own session, not by this repo. It must remain non-load-bearing — any agent using it MUST detect its absence and degrade to an explicit `unverified` report rather than erroring or blocking (N4 still applies: a validator that cannot validate returns `reject`, never silence). No other MCP namespace may appear in any agent allowlist. This exception exists because no other mechanism lets an agent confirm that rendered output is actually correct — the gap that let a Phase 1 renderer pass typecheck, lint, 25 tests, build and bundle-budget while displaying a black screen (see `memory/invariants.md`, 2026-07-26).

**N9 — Preserved-Invariants contract on revision.** Any agent revising an existing artifact must explicitly list "Preserved Invariants" vs "Changed Behaviors" in its output and halt (not silently proceed) if a change would contradict a previously preserved invariant recorded in `memory/invariants.md`.

**N10 — Single-user scope.** FABLE-HARNESS is built for the operator's own individual interactive use. It never routes another person's request through this seat, and it is never wired into a shared/multi-tenant service. (Keeps subscription/OAuth auth squarely in the compliant usage tier — see `max-your-cc-sub` research findings in `plan.md`.)

**N11 — User-scope install never clobbers.** The `install-user-scope` skill only ever merges into `~/.claude/` — it converts an existing whole-directory symlink into per-file symlinks preserving every prior owner's files before adding its own, read-merges `settings.json` hook arrays and `availableModels` without deleting existing keys, and always shows a dry-run preview requiring explicit confirmation before writing anything.

## Precedence

On conflict: N1 > N2 > N4 > N3 > N5 > N6 > N7 > N8 > N9 > N10 > N11. In practice these rarely conflict — they were designed to be independent.

## Citation convention

When any agent or hook refuses an action or downgrades a verdict because of one of these invariants, it must cite it in this exact greppable form: `Refused per N<k>: <short reason>`.
