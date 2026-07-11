# Decision: cmux/wmux integration — optional operator visibility layer, not a harness dependency

**Context**: User asked whether cmux (a terminal multiplexer purpose-built for running multiple AI coding-agent CLI sessions in parallel) could be incorporated into FABLE-HARNESS's multi-session/multi-agent story.

**Decision**: cmux itself is a native macOS app (Swift/AppKit/libghostty) and cannot run on this Windows host. Its Windows-compatible sibling is `wmux` (amirlehmam/wmux, an independent, protocol-compatible reimplementation using ConPTY + Electron) — younger and less vetted than upstream cmux, but the only option that actually runs here. Neither cmux nor wmux depends on MCP or headless/-p mode (confirmed via research — a separate, unrelated third-party project `cmux-agent-mcp` wraps cmux in an MCP server and should be avoided/ignored, not adopted). Neither has native git-worktree support (an open, unimplemented GitHub issue, #3414, proposes it) — so there is nothing to replace in FABLE-HARNESS's existing worktree-isolation mechanism.

**Alternatives considered**: (a) do nothing, treat as out of scope; (b) require wmux as a dependency for multi-session work; (c) add a small, guarded, opt-in notification hook that no-ops silently when wmux/cmux isn't installed.

**Chosen**: (c). cmux/wmux is purely a terminal-hosting GUI + notification layer sitting downstream of the harness — it should never be a required dependency, only an optional visibility enhancement for operators who choose to install it, consistent with CONSTITUTION N8 (interactive-CLI-only, no forced extra infrastructure).

**Consequence**: Added `.claude/hooks/handoff-notify.ps1` (+ `.sh` mirror), a `PostToolUse/Write` hook that checks whether the just-written file matches the `.fable/<run_id>/handoffs/*.json` pattern (FABLE-HARNESS's existing file-mediated cross-session coordination mechanism, per AGENTS.md's Multi-Agent Systems section) and, only if a `wmux` or `cmux` binary is found on PATH, shells out to `wmux notify "<summary>"` (or emits a bare OSC 9 terminal escape sequence otherwise, which is a harmless no-op in terminals that don't understand it). This turns file-mediated handoffs into a glanceable "a session is waiting on you" signal for operators running wmux/cmux, with zero change to the underlying handoff mechanism and zero dependency for operators who don't use either tool.

**Owner**: harness maintainer. **Review date**: revisit if/when Claude Code's own Agent Teams feature gains native cross-session visibility, which would likely obsolete this hook.
