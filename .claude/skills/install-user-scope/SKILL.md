---
name: install-user-scope
description: Merge-safe installer that makes FABLE-HARNESS's agents/skills/hooks available at Claude Code's user scope (~/.claude), so they work across every project, not just H:\FABLE-HARNESS. Manual-only — never auto-invoked, since this touches shared, hard-to-reverse state outside this project.
disable-model-invocation: true
---

# /install-user-scope — merge-safe user-scope installer

**This is manual-only** (`disable-model-invocation: true`) because it writes to `~/.claude/`, which other projects (e.g. pair-programmer, AgentSmith) already share and depend on. CONSTITUTION.md N11 ("user-scope install never clobbers") governs this entire skill.

## What was discovered during planning (do not re-derive this — it's already confirmed)

`~/.claude/agents` and `~/.claude/skills` are, on this machine, **whole-directory symlinks** into `H:\pair-programmer\.claude\...`. A naive "symlink our folder over theirs" install would silently destroy that project's install. `~/.claude/settings.json` hooks are additive arrays already containing pair-programmer + AgentSmith entries — they must be read-merged, never overwritten.

## Procedure (follow exactly, in order — do not skip the dry-run or the confirmation)

1. **Always run the dry run first**, with no exceptions:
   ```
   pwsh -NoProfile -File H:\FABLE-HARNESS\.claude\scripts\install-user-scope.ps1 -DryRun
   ```
2. **Show the full dry-run output to the user verbatim.** It lists exactly which files will be converted, which per-file symlinks will be created, and how `settings.json` will be merged (or flags a conflict if `availableModels` already exists and includes `fable`, which requires manual resolution — never auto-resolved).
3. **Ask the user to explicitly confirm** via `AskUserQuestion` — something like "Apply this install-user-scope plan? This will modify ~/.claude/agents, ~/.claude/skills, and ~/.claude/settings.json." Do not proceed on an ambiguous or implied yes; this is a hard-to-reverse, shared-state action per the standing safety guidance (always confirm first for actions like this).
4. **Only on an explicit yes**, run:
   ```
   pwsh -NoProfile -File H:\FABLE-HARNESS\.claude\scripts\install-user-scope.ps1 -Confirm
   ```
5. Report what actually changed (files created, settings.json keys merged) and remind the user that FABLE-HARNESS's agents/skills are now available from any project directory, while every prior project's install was preserved.

## What this skill must NEVER do

- Never run the `-Confirm` pass without a completed dry-run shown to the user first.
- Never delete or overwrite an existing file under `~/.claude/agents` or `~/.claude/skills` — the installer script itself already refuses to (`SKIP` on any name collision), but do not attempt to work around that by deleting the pre-existing file yourself.
- Never silently resolve an `availableModels` conflict where an existing setting already includes `fable` — that is a genuine policy conflict (CONSTITUTION N2) requiring the user's explicit manual decision, not an automatic merge.
