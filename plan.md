# FABLE-HARNESS: Claude Code CLI All-in-One Dev Platform

## Status: BUILD COMPLETE (2026-07-10) — all 8 phases built and live-tested; see below

The harness described in this plan has been fully built at H:\FABLE-HARNESS and validated with three real end-to-end `/run` executions (not just structural checks). Final inventory: **32 agents, 11 skills, 2 Workflow scripts (`run.js`/`review.js`), 6 hooks, 5 rubrics, 4 profiles, 3 team-configs, 1 merge-safe user-scope installer.** Zero `model: fable` outside `.claude/skills/plan-deep/SKILL.md`; zero MCP tool references anywhere; constitution hash verified.

Live end-to-end testing (per user's explicit request) found and led to fixing **8 real bugs** that pure structural/syntax validation would never have caught — see `memory/decisions/2026-07-10-live-validation-findings.md` in the project for full detail:
1. `args` arriving as a JSON-encoded string rather than an object inside Workflow scripts (fixed with defensive normalization in both `run.js` and `review.js`).
2. `reflexion-coach` was never actually dispatched on a reject verdict, so Reflexion ×1 never fired (fixed — `run.js`'s `runStage()` now properly wires the retry loop).
3. `reflexion-coach.md`'s stage-file schema didn't match the canonical schema used by `verify-gate`/the Stop hook (fixed — standardized on `verify_loops`/`reflexion_used`/`last_verdict`/`history`).
4. `missability-inspector` only wrote its evidence file on the failing path, and was missing `Write` from its own tools allowlist entirely (fixed on both counts).
5. `run.js` hardcoded `status: 'finalized'` regardless of whether `run-finalizer` actually agreed to finalize (fixed — now trusts a schema-validated `{finalized, reason}` return).
6. `bash-whitelist.ps1`'s command splitter broke on a literal `|` inside a quoted string (e.g. a grep regex) — fixed with quote-aware splitting.
7. Same splitter didn't recognize shell control-flow keywords (`if`/`then`/`fi`/etc.) as structural, denying them as unknown commands — fixed by allow-listing them.
8. (Confirmed correct, not a bug) The Codex Rubber-Duck Bridge correctly normalized a genuine `codex exec` usage-limit failure to a hard `reject` per N4, proving its failure-handling path works.

Also delivered beyond the original plan, per mid-build user requests: a researched-and-documented cmux/wmux integration decision (optional, guarded `handoff-notify` hook — cmux itself is macOS-only and can't run on this host) and a documented known limitation (FABLE-HARNESS's agent names collide with pair-programmer's at user scope, since the roster was deliberately modeled on pair-programmer's own registry — harmless within FABLE-HARNESS itself since project scope always wins, but limits cross-project reuse of the specific implementations until/unless a rename is warranted).

`plan.md` is also saved at the project root (`H:\FABLE-HARNESS\plan.md`) per user request.

---

## Status: research complete + cross-vendor (Codex CLI) plan review complete — final plan below, incorporating fixes; research log preserved further down for reference

---

# FINAL PLAN (v2 — revised after Codex CLI adversarial review)

## Context

The user wants H:\FABLE-HARNESS built into a best-in-class, all-in-one software-development platform, using *only* Claude Code's native interactive-CLI primitives — no MCP servers, no `-p`/headless mode. Two seed documents already exist there: `taxonomy_blueprint.md` (a 16-section SDLC taxonomy: strategy → retirement) and an enterprise MCP/LangGraph orchestration research doc (concepts useful, literal MCP implementation not applicable here). The directory is otherwise empty — no `.claude/` yet.

Extensive research (three parallel background streams, fully logged below) surveyed: (1) five mature sibling repos for reusable governance/quality patterns; (2) eight disler reference repos for planning, verification, safety-hook, and observability patterns; (3) official Anthropic/Claude Code docs for exact hook/agent/skill schemas. **The resulting v1 architecture was then run through an independent adversarial review using `codex exec` (OpenAI Codex CLI, confirmed installed and working via `codex exec --sandbox read-only --skip-git-repo-check`) as a genuine cross-vendor second opinion.** That review found real errors, which are fixed in this v2: an invented `.claude/teams/*.yaml` primitive (the real reusable-orchestration surface is `.claude/workflows/*.js`, consumed by the Workflow tool — exactly what this very session already uses), a Fable-5 enforcement story that only covered agent/skill frontmatter and missed other model-selection surfaces (`CLAUDE_CODE_SUBAGENT_MODEL`, `/model`, `/advisor`/`advisorModel`, `teammateDefaultModel`, `availableModels`), a factually wrong claim that `disable-model-invocation` is a subagent field (it is skill-only), a Stop-hook-before-verifier-exists bootstrap ordering bug, an arithmetic mismatch in the agent count, and an overstated claim about Agent Teams supporting nested "team leads talking to team leads."

**User's explicit constraints** (all incorporated below):
1. Opus, Sonnet, and Haiku may be freely auto-routed per agent/task tier. **Fable-5 must never be auto-routed** — reachable only via an explicit user-typed command, or via an agent's suggestion that the user must explicitly approve first.
2. The harness must be installable at **user scope** so it works across all projects, not just H:\FABLE-HARNESS.
3. Must support using **Codex CLI as a cross-vendor "rubber duck" judge**.
4. Must support the full range of Claude Code agent-to-agent systems: plain hierarchical sub-agents, Agent Teams, and team-lead-to-team-lead coordination each optionally running their own sub-agents — implemented honestly against what Claude Code actually supports (see the corrected Multi-Agent Systems section below; the naive "peer team leads" framing was Codex-flagged as overstated and is corrected here).

## Approach

Translate every MCP-dependent execution pattern from the sibling repos into pure primitives:
- `mcp__pp_harness__*` calls → Task-tool subagent dispatch + local files under `.fable/<run_id>/` (replaces the SQLite-backed ledger).
- Cross-vendor judging → different Claude model tiers judging each other (Sonnet generates, Opus judges), **and/or a concretely-specified Bash shell-out to `codex exec`** (see Codex Rubber-Duck Bridge section) — no MCP wrapper.
- Memory fabric (episodic/semantic/procedural) → plain directories + append-only files under `memory/` (curated, committed) layered on top of Claude Code's own built-in auto-memory (uncurated, automatic, coexists — do not fight it).
- Reusable orchestration → **`.claude/workflows/*.js`** Workflow-tool scripts (the real, confirmed-working primitive used throughout this very session), NOT a fictional YAML "teams" config format. Agent Teams (experimental, opt-in) reserved only for genuine live peer-to-peer coordination within a single session.

### Directory layout

```
H:\FABLE-HARNESS\
├─ CONSTITUTION.md          # invariants (incl. Fable-manual-only) + SHA-256 hash anchor
├─ AGENTS.md                # cross-tool behavioral contract / project layout rules
├─ CLAUDE.md                # session-start routing table + @-imports
├─ README.md
├─ plan.md                  # this plan, saved to project root per user request
├─ taxonomy_blueprint.md    # already exists — do not regenerate
├─ .claude\
│  ├─ settings.json         # hooks + permissions + env + availableModels (committed)
│  ├─ settings.local.json   # personal overrides, gitignored (e.g. telemetry toggle)
│  ├─ agents\               # 32 subagent .md files (roster below)
│  ├─ skills\               # 11 skill folders <name>/SKILL.md (roster below)
│  ├─ workflows\            # *.js Workflow-tool scripts — the REAL orchestration primitive
│  │                        #   (run.js, review.js, best-of-n.js) — replaces the fictional
│  │                        #   "teams/*.yaml" concept from v1
│  ├─ hooks\ (+ hooks\lib\) # hook scripts, .ps1 primary + .sh mirror, fail-open
│  ├─ team-configs\         # plain YAML data files (stage lists, rubric refs per pipeline)
│  │                        #   READ BY workflows/*.js scripts — documentation/config data,
│  │                        #   not a native Claude Code primitive itself
│  ├─ rubrics\              # judge rubrics (rfc-2119, c4, openapi, owasp-asvs, wcag)
│  └─ profiles\             # project-archetype profiles (web-ui, api, cli, ai-agentic)
├─ ai_docs\                 # offline grounding copies (hooks/subagents/skills reference,
│                           #   model-routing-and-fable-policy, prompting-quirks)
├─ memory\                  # OUR curated memory (committed) — distinct from auto-memory
│  ├─ decisions\<date>-<slug>.md   # append-only decision records (context/decision/
│  │                                 alternatives/consequences/owner/review-date)
│  ├─ invariants.md         # preserved-invariants ledger
│  ├─ glossary.md
│  └─ index.jsonl           # append-only keyword index
└─ .fable\                  # gitignored run-state (replaces the MCP SQLite ledger)
   ├─ runs.jsonl
   ├─ fable-approval.token  # short-lived file written ONLY after an explicit user "yes" to a
   │                        #   Fable-5 escalation prompt; see Fable Enforcement section
   └─ <run_id>\{run.json, taxonomy_map.json, stages\*.json, verdicts\*.json,
              missability.json, artifacts\*, telemetry.jsonl,
              codex-review-<stage>.md, verdicts\<stage>-codex.json}
```

### Fable-5 enforcement — corrected, multi-surface (Codex-flagged as the top issue in v1)

v1's mistake: it treated "never write `model: fable` in auto-invocable agent/skill frontmatter" as sufficient. Codex's review confirmed (citing the live docs) that Claude Code has **several independent model-selection surfaces**, any one of which could reach Fable-5 if left unaddressed: subagent frontmatter `model:` field, a per-invocation `model` parameter when dispatching Task, the `CLAUDE_CODE_SUBAGENT_MODEL` environment variable, the interactive `/model` command, `/advisor`/`advisorModel`, `teammateDefaultModel` (Agent Teams), and the project/user `availableModels` setting. The v2 policy addresses all of them:

1. **`.claude/settings.json` sets `availableModels` to exclude Fable-5 from the default/auto-routed model pool for the main interactive session and for all subagent/teammate dispatch.** This is the primary structural gate — if Fable isn't in the available set, no auto-routing path (frontmatter, env var, per-invocation param, teammate default) can silently select it.
2. **No agent file (`.claude/agents/*.md`) ever sets `model: fable`.** (Confirmed correct per Codex: `disable-model-invocation` is a *skill*-only field, not a subagent field — so v1's phrase "Fable-only agents gated by disable-model-invocation" was wrong and is removed. Fable is *only* ever set in a skill's frontmatter, never a bare agent's.)
3. **Fable is reachable only through one explicit, manual skill: `plan-deep`**, gated by `disable-model-invocation: true` (the correct, skill-only field) so Claude can never auto-invoke it — only a user typing `/plan-deep` can.
4. **The suggestion-and-approval flow lives entirely in the interactive main-loop / skill layer, never inside a `Workflow()` script call** (Codex correctly flagged that Dynamic Workflows have no mid-run human input beyond permission prompts, so a workflow cannot pause mid-pipeline to ask "use Fable?" and resume in the same run). Concretely: an agent that judges a task Fable-worthy stops and uses `AskUserQuestion` in the normal conversational turn (not inside a workflow script). If the user says yes, the harness writes a short-lived `.fable/fable-approval.token` (single-use, run-scoped) and *only then* does a **separate, freshly-invoked** `/plan-deep` skill call proceed with `model: fable`. If the user says no, the token is never written and the original tier (Sonnet/Opus) continues. This makes the approval step a genuine second, distinct action rather than a mid-workflow branch.
5. **A `UserPromptSubmit` hook denies any literal `/model fable` or `/advisor` switch to Fable unless `.fable/fable-approval.token` exists and is unconsumed** — closing the direct manual-override surfaces too, so even a user's own typo or a suggestion-injection attempt can't silently flip the session default; the token is the single source of truth for "approved right now."
6. **`ai_docs/model-routing-and-fable-policy.md` and the `model-routing` skill document all six surfaces above explicitly**, so any future agent/skill authored by `meta-agent` is grounded in the full policy, not just the frontmatter convention.

### Multi-Agent Systems — corrected to match what Claude Code actually supports

v1 claimed "peer team leads each running their own sub-agents," which Codex correctly flagged as overstated. The real, documented capabilities (and how FABLE-HARNESS uses each honestly):

1. **Hierarchical Task-tool sub-agents** (fully supported): any agent or the main session dispatches a Task sub-agent, which runs in a fresh, isolated context and reports a single summary back. This is the default fan-out mechanism throughout the harness (via `.claude/workflows/*.js` pipeline/parallel calls).
2. **Agent Teams** (experimental, opt-in via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`): one lead + teammates *within a single session*, coordinating via a shared task list. Confirmed real limitations: **one team per session, no nested teams, a teammate cannot become a lead, and no *background* subagents may be spawned from an in-process teammate.** What teammates CAN still do: ordinary foreground Task-tool sub-agent dispatch during their own turn (that's just standard sub-agent delegation, not nested teaming) — so "a teammate that also uses a sub-agent to do a piece of research" is legitimate; "a teammate that becomes its own team lead with its own team" is not, and the harness will never attempt that.
3. **Cross-session "team lead to team lead" coordination** (the honest answer to the user's ask): Claude Code has **no native session-to-session messaging primitive**. The harness achieves the spirit of this via **file-based coordination**: multiple independent top-level sessions (launched via `claude --worktree <name>`, viewable together in Agent View) each optionally run their own single-lead Agent Team, and coordinate asynchronously by reading/writing shared envelope files under `.fable/<run_id>/handoffs/*.json` (a lightweight reimplementation of Hydra's typed cross-squad envelope pattern from the research, using plain files instead of a daemon). This is documented plainly in `AGENTS.md` and the `run` workflow as "async, file-mediated cross-session coordination," not a native message bus — so no future agent is misled into assuming a message actually crosses sessions in real time.
4. **`.claude/workflows/*.js` (the Workflow tool)** remains the default, cheapest, non-experimental fan-out mechanism for everything that doesn't need live peer coordination — pipeline/parallel across sub-agents within one session. This is what `run.js` and `review.js` are built on (see Skill/Workflow roster below), and is the *only* orchestration primitive treated as load-bearing; the old `.claude/teams/*.yaml` idea is now just plain YAML **data** under `team-configs/` that a `workflows/*.js` script reads — not a Claude Code primitive itself.

### Codex Rubber-Duck Bridge — concretized (Codex flagged v1's version as a hand-wave)

Confirmed working invocation today: `codex exec --sandbox read-only --skip-git-repo-check "<prompt>"` (non-interactive, read-only sandbox, no git-repo requirement). The `judge-cross-vendor` agent uses a fixed, deterministic contract:
1. Write the full review prompt (task context + artifact + rubric) to `.fable/<run_id>/codex-review-<stage>.md`.
2. Invoke via Bash: `codex exec --sandbox read-only --skip-git-repo-check "$(cat .fable/<run_id>/codex-review-<stage>.md)"`, capturing stdout.
3. Normalize Codex's free-text verdict into `.fable/<run_id>/verdicts/<stage>-codex.json` with a fixed schema: `{verdict: "pass"|"pass-with-notes"|"reject", issues: [...], raw_output_path: "..."}` (the same 3-verdict vocabulary used everywhere else in the harness).
4. `reject` is treated as a hard stage failure requiring the Reflexion ×1 retry, exactly like a same-vendor Opus reject — Codex is a genuine equal-weight cross-vendor judge, not an advisory afterthought.

### User-scope install — concretized (new, addresses a real conflict discovered during planning)

Discovered fact: `~/.claude/agents` and `~/.claude/skills` are *currently whole-directory symlinks* into `H:\pair-programmer\.claude\...`, and `~/.claude/settings.json` hooks are additive arrays already containing pair-programmer + AgentSmith entries. A naive "symlink our whole folder over `~/.claude/agents`" install would silently destroy the existing pair-programmer install. The harness ships a manual, explicit `install-user-scope` skill (never auto-run) that:
1. Detects whether `~/.claude/agents`/`~/.claude/skills` are already directory-level symlinks to another project; if so, **converts them to real directories containing one per-file symlink per existing file** (preserving every existing agent/skill from whatever project(s) already own them) before adding FABLE-HARNESS's own per-file symlinks alongside — merge, never clobber.
2. Read-merges (not overwrites) `~/.claude/settings.json`: appends FABLE-HARNESS's hook entries into each event's existing array, adds `availableModels` only if not already set by another tool (warns and asks if there's a conflict), and never deletes an existing key.
3. Prints a dry-run preview of every file it will touch and requires explicit confirmation before writing (this is a hard-to-reverse action per the standing safety guidance — always confirm first, never silently restructure another project's install).

### Agent roster — full taxonomy coverage, count corrected (32, not 33 — Codex caught an arithmetic error in v1)

User explicitly chose full taxonomy coverage over a lean roster, closer to pair-programmer's own ~70-agent depth. Modeled directly on pair-programmer's real, proven agent roster (confirmed via its live agent registry during research), pruned of what doesn't belong in a general-purpose harness: drop game-dev agents (economy-designer, level-designer, narrative-designer, encounter-designer, tech-animator, technical-artist, game-ai-programmer, game-accessibility-specialist), drop ExecutiveSuite C-suite personas (ceo/cfo/cmo/etc. — a different product), drop Hydra/AgentSmith-specific squad/constitution-daemon agents (hydra-*, smith-quarantine, smith-replicator, sentinel-watcher — their *patterns* are absorbed into our CONSTITUTION.md and hooks instead of separate agents). Every kept agent's `tools:` allowlist is stripped of MCP tool names and rebuilt on Read/Write/Edit/Glob/Grep/Bash + Task dispatch, per the MCP→primitives translation. **No agent file ever carries `model: fable`** (that's skill-only, per the corrected Fable Enforcement section above).

**A. Orchestration &amp; lifecycle control (10, mostly haiku/sonnet — cheap and frequent):**
`triage` (haiku — trivial/standard/major classifier), `profile-loader` (haiku — loads `.claude/profiles/*.yaml`, detects project archetype), `taxonomy-mapper` (haiku — maps request to ≥1 of 16 sections with floor), `judge-router` (haiku — decides same-tier vs cross-tier judging), `judge-cross-vendor` (opus — cross-tier critique when gate_eligible; "cross-vendor" reinterpreted as a different model tier or literal `codex`/`gemini` CLI shell-out if installed, never MCP), `reflexion-coach` (sonnet — bundles a failing verdict + critique into a retry prompt, enforces Reflexion ×1 hard cap), `missability-inspector` (haiku — runs the 20-item completion checklist before finalize), `oracle-evaluator` (sonnet — best-of-N Borda-count comparison for major-scope work), `master-plan-patcher` (sonnet — patches PROJECT_MASTER.md per taxonomy §9 after a run finalizes), `run-finalizer` (sonnet — writes run summary, archives best-of-N losers, calls the local finalize routine).

**B. Governance &amp; self-extension (4):** `agents-md-author` (sonnet — keeps AGENTS.md in sync with architecture/interfaces/standards/security sections), `governance-author` (sonnet — RACI, decision logs, review forums, cadence per §4.14), `meta-agent` (opus — authors new agents/skills/hooks from `agent-factory` templates; our AgentSmith-factory + hooks-mastery meta-agent equivalent), `verifier` (opus — independent read-only verifier per the-verifier-agent pattern: no shared context with builder, re-derives claims from disk, `pass|pass-with-notes|reject` + could-not-verify gaps).

**C. Strategy &amp; discovery, §4.1-4.2 (2):** `strategy-author` (opus — vision brief, business case, OKRs, kill-criteria), `discovery-researcher` (sonnet — research briefs, personas, journey maps, workflow maps, glossary).

**D. Product scope, §4.3 (1):** `spec-author` (sonnet — PRD, feature specs, acceptance criteria in RFC-2119 language; also used for bug-fix repro specs and refactor invariants).

**E. Experience design, §4.4 (3):** `designer` (sonnet — IA maps, user flows, the 8 interaction states, wireframes, content guides, accessibility plans), `design-system-curator` (sonnet — design tokens, component specs, component-preview artifacts; carries the DESIGN_VARIANCE/MOTION_INTENSITY/VISUAL_DENSITY dials), `visual-regression-runner` (haiku — screenshot diffing before/after touched routes/components, web-ui/mobile profiles only).

**F. Domain, data, analytics, §4.5 (1):** `data-modeler` (sonnet — entities/ERD, lineage, retention, migration plan, analytics events).

**G. Architecture, §4.6 (1):** `architect` (opus — ADRs + C4 sketches as Mermaid, text not code).

**H. Interfaces &amp; contracts, §4.7 (1):** `api-designer` (sonnet — OpenAPI 3.1 / AsyncAPI 3 contracts, route inventory, versioning/error/retry semantics).

**I. Engineering implementation, §4.8 (1):** `engineer` (sonnet — the only code-writing producer; fanned out N-wide in worktrees for best-of-N on major scope).

**J. Security/privacy/compliance, §4.9 (1):** `security-reviewer` (opus — threat model, control mapping, OWASP-ASVS mapping, privacy review; also covers ai-controls tool-permissions and retirement's data-lifecycle security concerns).

**K. Quality engineering, §4.10 (1):** `test-strategist` (sonnet — test strategy, contract tests, performance budgets, release-readiness criteria).

**L. Delivery &amp; release, §4.11 (1):** `release-planner` (sonnet — rollout, rollback, migration runbook, comms).

**M. Observability &amp; ops, §4.12 (1):** `ops-author` (sonnet — SLOs, telemetry taxonomy, dashboards, alerts, runbooks).

**N. Documentation, §4.13 (1):** `docs-author` (haiku — changelogs, release notes, runbooks, user docs, content guides — the trivial-scope floor artifact producer).

**O. AI/agentic controls, §4.15 (1):** `ai-controls-author` (sonnet — AI system spec, eval suite, tool-permission matrix, HITL workflow).

**P. Retirement, §4.16 (1):** `retirement-planner` (sonnet — EOL plan, migration guide, archive/retention, sunset comms, shutdown checklist).

**Q. Live-quality/browser (1):** `browser-validator` (sonnet — boots the dev server, drives acceptance-criteria flows via claude-in-chrome, scans console/network; web-ui/mobile profiles).

Corrected total: A(10) + B(4) + C(2) + D(1) + E(3) + F(1) + G(1) + H(1) + I(1) + J(1) + K(1) + L(1) + M(1) + N(1) + O(1) + P(1) + Q(1) = **32 named agents** (v1 mis-added this to 33; C-Q domain producers alone are 18, not 19 — fixed here). This covers exactly what pair-programmer's own roster covers for a non-game, non-C-suite, non-squad-daemon project — genuinely full taxonomy coverage (all 16 sections have a named, dedicated owner or an explicit documented merge), while staying agent-count-comparable to a pruned pair-programmer (~32, vs its ~70 which includes ~25 game-dev + ~13 executive-suite personas deliberately excluded as out of scope). Game-dev/C-suite extensions are additive agent files later, via `agent-factory` — not a redesign.

### Skill roster (10 — corrected: v1 undercounted by omitting the everyday `plan` skill)

`plan-deep` (**the only file anywhere with `model: fable`**, gated by `disable-model-invocation: true` — planf3-inspired Markdown template: append-only metadata, `[]/[wip]/[x]/[f]` status markers, mandatory per-phase test loop, Questionables toggle, Amendments log; the Fable-approval-token check from the Fable Enforcement section is the first line of its body), `plan` (auto-invocable, Sonnet, everyday planning — the non-Fable default), `model-routing` (canonical tier table + the full six-surface Fable enforcement protocol, mirrored in `ai_docs/`), `taxonomy-map` (taxonomy-mapping-with-floor), `verify-gate` (dispatches `verifier`, enforces Reflexion ×1 + bounded-retry-then-escalate at 3 loops), `artifact-conventions` (where artifacts live, 3-verdict vocabulary, Preserved-Invariants-vs-Changed-Behaviors contract), `run` (thin wrapper that calls `Workflow({name: "run"})` — the actual pipeline logic lives in `.claude/workflows/run.js`), `review` (thin wrapper calling `Workflow({name: "review"})`, backed by `.claude/workflows/review.js`), `agent-factory` (templates + risk_class→evolution_policy table for the meta-agent), `constitution` (inspect/attest/amend), `install-user-scope` (the merge-safe installer from the User-Scope Install section — manual-only, never auto-invoked). **Total: 11 skills** (`plan-deep`, `plan`, `model-routing`, `taxonomy-map`, `verify-gate`, `artifact-conventions`, `run`, `review`, `agent-factory`, `constitution`, `install-user-scope`).

### Hooks (6 of the confirmed ~30 events, all fail-open, exit-2-not-1 to block — reordered per Codex bootstrap fix)

Wired in two batches to respect real dependencies (see corrected Build Sequence below — the Stop hook must NOT be wired until the `verifier` agent and `verify-gate` skill already exist, otherwise it points at machinery that doesn't exist yet):

**Batch 1 (wired in Phase 2, no dependencies):** `SessionStart` → constitution SHA-256 hash-attest (warn-only, never blocks startup). `PreToolUse/Bash` → whitelist-first (L4) safety gate using the confirmed `hookSpecificOutput.permissionDecision` contract, with command-normalization before matching. `PreToolUse/Edit|Write` → a `type: "prompt"` cheap-model (haiku) quality gate blocking obvious placeholder/secret-literal debris. `UserPromptSubmit` → the Fable-approval-token gate (denies `/model fable`/`/advisor`-to-Fable switches unless `.fable/fable-approval.token` exists and is unconsumed).

**Batch 2 (wired in Phase 3b, after `verifier` + `verify-gate` exist):** `Stop` → verifier gate with the mandatory `stop_hook_active` guard, gates the turn via exit 2 pointing at `/verify`, respects a persisted 3-loop escalation ceiling.

**Optional, either batch:** `PostToolUse`/`SessionEnd` → local jsonl telemetry emitter as a *second*, independent hook entry (dual-hook-per-event principle) — no server/dashboard by default, toggleable in `settings.local.json`.

### Memory

Two coexisting layers: Claude's own auto-memory (`~/.claude/projects/.../memory/MEMORY.md`, automatic, low-signal, left on) plus our curated `memory/` (committed, high-signal, written by agents via Write/Edit under `artifact-conventions`, `@`-imported from CLAUDE.md). CLAUDE.md states the distinction explicitly: auto-memory = what Claude noticed; `memory/` = what the team decided.

### Build sequence (8 phases, dependency-ordered — reordered per Codex's bootstrap-ordering fix)

0. Skeleton directories + `.gitignore` + populate `ai_docs/` grounding copies (including the six-surface Fable policy doc).
1. `CONSTITUTION.md` (invariants incl. Fable-manual-only + hash anchor) + `AGENTS.md` (documents the file-mediated cross-session coordination convention honestly) + `CLAUDE.md`.
2. **Hook Batch 1 only**: `SessionStart`, `PreToolUse/Bash`, `PreToolUse/Edit|Write`, `UserPromptSubmit` (Fable-token gate) + `.claude/settings.json` `availableModels` restriction. Smoke-test these before anything else exists — they have no dependency on any agent/skill.
3a. Orchestration/governance agents (14: sections A+B) + core skills EXCEPT `run`/`review`/`install-user-scope` (`model-routing`, `taxonomy-map`, `verify-gate`, `artifact-conventions`, `agent-factory`, `constitution`, `plan-deep`, `plan`) — this is where `verifier` gets created.
3b. **Now** wire **Hook Batch 2** (`Stop` → verifier gate) — only now does it point at a real, existing `verifier`/`verify-gate` stack. Smoke-test the Stop gate specifically at this point, not earlier.
4. 18 taxonomy-domain producer agents (sections C-Q), authored via the `meta-agent`/`agent-factory` templates (dogfoods the factory).
5. `.claude/workflows/run.js` + `review.js` (the real orchestration primitive) + their thin `run`/`review` skill wrappers + `.claude/team-configs/*.yaml` (plain data, not a primitive) + `.claude/rubrics/*.md` + `.claude/profiles/*.yaml` + the `judge-cross-vendor` agent's Codex Rubber-Duck Bridge script.
6. `install-user-scope` skill (built last since it depends on every other file existing to symlink).
7. Validation (see below).

### Critical files to get right first
- `H:\FABLE-HARNESS\CONSTITUTION.md` — everything else cites it.
- `H:\FABLE-HARNESS\.claude\settings.json` — hooks, permissions, and `availableModels` (the primary Fable gate) all live here.
- `H:\FABLE-HARNESS\.claude\skills\model-routing\SKILL.md` — the full six-surface Fable policy.
- `H:\FABLE-HARNESS\.claude\workflows\run.js` — the real MCP-free lifecycle driver (not a YAML file).
- `H:\FABLE-HARNESS\.claude\agents\verifier.md` — the independent-verification contract the Stop-gate depends on (must exist before the Stop hook is wired).

### Verification plan (updated to test in dependency order, per the fixed build sequence)
After Phase 2: confirm `SessionStart` prints the hash-attest banner; trigger the whitelist Bash hook with a deliberately blocked command (e.g. `rm -rf`) and confirm exit 2 + deny reason; confirm typing `/model fable` (or equivalent) is denied absent an approval token. After Phase 3b: confirm the Stop hook now fires and gates on the verifier stack (this specifically could NOT be honestly tested before this point). After Phase 7: run `/constitution` to confirm hash-attest passes; run `/run <trivial request>` and confirm only a changelog artifact is produced (taxonomy floor); run `/run <standard feature request>` end-to-end via `.claude/workflows/run.js` and inspect `.fable/<run_id>/` for correct stage/verdict/missability files, including a `judge-cross-vendor` stage that actually shells out to `codex exec` and produces a `verdicts/<stage>-codex.json`; confirm no agent/skill file anywhere contains `model: fable` outside `plan-deep`; confirm the Fable AskUserQuestion-then-token-then-separate-plan-deep-call flow end to end (suggest → user says yes → token written → `/plan-deep` runs with Fable → token consumed).

---

## Status: research complete (background streams below preserved for reference)

## Confirmed constraints (from user)
- Interactive Claude Code CLI only — NO `-p`/print mode, NO MCP servers in the built harness.
- CLI tools, daemons, and TypeScript tooling are allowed as long as everything is invoked/used from within an interactive CLI session (no headless-only components).
- Model routing policy:
  - **Opus 4.8, Sonnet 5, Haiku 4.5** — may be auto-routed/assigned per agent or task tier as part of the harness's model-tier strategy.
  - **Fable 5** — must NEVER be auto-routed. It may only be invoked (a) manually by explicit user command, or (b) suggested by the harness with the user's explicit approval before use. This must be enforced structurally (e.g., no agent/skill frontmatter defaults to fable-5; any fable-5 path goes through an AskUserQuestion-style confirmation or an explicit `/`-command the user types).

## Research in flight (background)
1. Explore agent — sibling repo survey: pair-programmer, Hydra, AgentSmith, TheEights, AI-Agent-UI-UX-Creator (.claude/ structures, agent/skill/hook patterns, MCP-dependent vs pure-primitive patterns).
2. Explore agent — disler reference repos: pi-vs-claude-code, planf3 (fable-enhanced planning), the-verifier-agent, bash-damage-from-within, max-your-cc-sub, claude-code-hooks-mastery, bowser, claude-code-hooks-multi-agent-observability.
3. deep-research workflow — official Claude Code docs (features, sessions, workflows, worktrees, hooks-guide, sub-agents, agent-teams, channels, goal, common-workflows, best-practices, prompt-library) + Anthropic prompting docs (Fable-5, Opus 4.8, Sonnet 5, best practices, use-case overview).

## Source documents (read in full)
- `taxonomy_blueprint.md` — 16-section SDLC taxonomy (strategy → retirement), artifact/owner/dependency matrix, governance forums, completion checklist, game-dev profile extensions. This is the CONTENT taxonomy the harness's agents/skills should be organized around (maps cleanly to pair-programmer's existing taxonomy-driven pipeline).
- `Enterprise Master AI Orchestration System Architecture.md` — MCP/LangGraph-centric enterprise orchestration research (C-Suite/Engineering/Creative squads, state machine, memory fabric, HITL). Useful for CONCEPTS (hierarchical delegation, squad boundaries, memory tiers, HITL checkpoints, decision-record logging, budget/cost governance) but its literal MCP/LangGraph implementation must be reinterpreted into pure Claude Code primitives (agents+skills+hooks+memory files+workflows) since no MCP is allowed in this harness.

## Research findings — sibling repo survey (COMPLETE)

### Directory convention to adopt
`.claude/{agents, commands/<namespace>/, skills/<name>/SKILL.md, hooks, teams, rubrics, profiles}` + root `CONSTITUTION.md` / `AGENTS.md` / `CLAUDE.md` + a taxonomy/blueprint doc. Skip a `.github/` mirror (pair-programmer pays a real dual-maintenance tax for Copilot parity we don't need).

### Frontmatter conventions to keep
`name`, `model` (pin cheap models to cheap/classifier agents), `description` (dense, includes trigger conditions — critical for auto-invocation), `tools:` (explicit allowlist — the delegation-contract mechanism even with no MCP), `skills:` (list), occasional `color:` / `maxTurns:` (explicit turn budgets per agent role).

### Replace MCP/daemon execution with (core translation strategy)
- Task-tool sub-agent delegation instead of `mcp__pp_harness__*` tool calls.
- Local file-based state: JSON/YAML run ledgers under `.fable/<run_id>/` instead of an MCP-backed SQLite ledger.
- Hook scripts (PowerShell primary, since Windows; Bash tool also usable) that read/write those local files directly instead of querying a daemon.
- "Cross-vendor" judging → different Claude model-tier/persona judges the same artifact (Sonnet generates, Opus judges) OR literal shell-out to `codex`/`gemini` CLIs via Bash from inside an agent (no MCP wrapper needed) if those CLIs are installed.
- Memory fabric (Working/Episodic/Semantic/Procedural/Meta — CoALA-aligned, from TheEights) → implementable as plain directories + jsonl append logs + a simple keyword index; skip vector DB, or use Claude Code's own memory system (per-session `memory/` dir) as the substrate already required by this environment.

### Governance/quality patterns to port wholesale
- **Constitution + session-start hash-attest**: SessionStart hook computes SHA-256 of the harness's own CONSTITUTION.md, compares to a checked-in expected hash; drift → banner/block. No daemon needed.
- **Invariant citation convention**: `Refused per N<k>: <reason>` — greppable audit trail.
- **Fail-closed validators, 3 verdict values only** (pass / pass-with-notes / reject) — "a validator that cannot validate has already failed."
- **Quarantine 3-criteria release**: HITL approval + re-inspection against current rules + originating signal no longer firing.
- **Risk_class → evolution_policy table**: low=auto-commit, medium/high/critical=HITL escalating.
- **Missability checklist gate before finalize** (pair-programmer's 20-item list + AI-Agent-UI-UX-Creator's 8-state UI-component checklist as a domain-specific analog).
- **Reflexion ×1 cap** (one retry-with-critique per stage, enforced by convention/hook, not server).
- **Best-of-N + Borda count** for major-scope work, declared per stage in a team YAML.
- **Taxonomy-mapping-with-floor**: every request maps to ≥1 of the 16 taxonomy_blueprint.md sections; trivial requests still get a floor artifact (e.g., changelog entry).
- **`plan_only` vs `execute` mode** declared per command/agent — enhancement/advisory requests default to docs-only unless explicitly approved (complements but doesn't replace Claude Code's global Plan Mode).
- **Prompt-type PreToolUse hooks** (`type: prompt`, cheap model like Haiku, narrow scope) as an LLM-as-hook-judge quality gate on Write/Edit — genuinely novel, directly portable, no daemon required (seen in AI-Agent-UI-UX-Creator's frontend-design skill blocking "AI-tell" patterns).
- **Never-silently-swallow-a-dependency-failure counter**: retry once, count failures, surface past a threshold (e.g., 3) rather than silently degrading.
- **Spec-invariant preservation contract**: when revising an existing artifact, explicitly list "Preserved Invariants" vs "Changed Behaviors," halt if contradicted.

### Hard lessons / cautions (explicitly called out in source repos)
- **Never substitute `general-purpose` for a typed producer agent** — breaks audit/replay provenance (Hydra cites a ~10-attempt incident).
- **Design long workflows as one-shot-per-turn with explicit checkpoint+resume**, not "background and poll" — a spawned agent does not stay addressable as a persistent process; resume by re-invoking with a workflow_id that reloads checkpoint state.
- **Cap fan-out per turn** (envelope ceiling, e.g. 30), not just a global cap.
- **Hooks must fail open on internal errors** (`try{...} catch { exit 0 }`) — never let a hook bug block session start.
- **Avoid vendor-per-agent proliferation** and settings/hook cruft accumulation (AI-Agent-UI-UX-Creator has `.bak`/`.backup-*` remnants as a caution).
- **Replicator/fan-out quota math** template: `target = min(ceil(load/per_worker_capacity), risk_tier_cap, global_ceiling)` — reusable for capping parallel Task sub-agents.

### Notable novel mechanisms worth adopting directly
- Dual-register agent output: in-character/narrative body + strict machine-readable YAML output contract underneath (AgentSmith).
- Design dials (`DESIGN_VARIANCE`/`MOTION_INTENSITY`/`VISUAL_DENSITY`, 1–10) inferred by product archetype, for design-agent taste parameterization (AI-Agent-UI-UX-Creator) — check our own design agents/skills against this for robustness per user's explicit ask.
- Cross-platform hook pairs (.ps1 + .sh) with regex command-normalization before dangerous-pattern matching — template for our PreToolUse Bash-safety hook (we're Windows/PowerShell-primary per environment, but keep the normalization-before-matching technique).

## Research findings — disler reference repos (COMPLETE)

### planf3 (fable-enhanced planning) → adopt as meta-skill for our planning agent
- **Meta-skill pattern**: one skill owns "how we plan" (a fixed template), every specific plan is an instance of it — not ad hoc prompting each time.
- Plan template load-bearing sections to replicate (Markdown, skip the HTML/image-gen overhead — that part is cosmetic):
  - **Append-only metadata header** (created/modified/commits/agent/session/back-forward refs) — durable audit trail across sessions without a database.
  - **Status-marker vocabulary** `[]` idle / `[wip]` / `[x]` done / `[f]` failed, updated live on disk — survives context compaction since it's file-based, not conversational state.
  - **Per-phase mandatory "Testing Strategy" loop**: don't advance to the next phase until every check passes; fix-and-retry loop with an explicit escape hatch (`[f]`) to avoid stalling forever.
  - **Global Validation Commands** section: final gate across the whole plan, same loop discipline.
  - **Conditional "Questionables" toggle**: forces surfacing open assumptions/decisions instead of silently deciding, controlled by a simple flag — ask-vs-assume governance knob.
  - **Notes** (free canvas) + **Amendments** (append-only post-execution change history).
- "Fable" angle: the design thesis is spend more tokens/structure/visual grounding upfront on higher-capability models to compress the review loop later — not a literal separate API integration. Relevant to our Fable-5-manual-only planning-enhancement idea: Fable-5 could be the *suggested* model for authoring exceptionally thorough/structured plans on big asks, offered as an opt-in suggestion, never auto-selected (matches user's explicit constraint).
- **AMENDMENT (2026-07-10):** the "skip the HTML/image-gen overhead — that part is cosmetic" call above was **reversed** this session at the user's request. `plan-deep` and `plan` now emit planf3's actual **HTML-first** format with `<figure>` image slots and a **manual, N8-safe, local-CLI** image pipeline (`.claude/skills/lib/plan-template*.html` + `plan-images.ps1`/`.sh`). Image *generation* stays **manual-only** for now (prompt sheet via `extract` → generate externally when credits allow → `apply` swaps in `<img>`; no auto API), so the low-credit path is first-class. Full rationale + Preserved/Changed in `memory/decisions/2026-07-10-plan-html-image-generation.md`. Orchestrated via Hydra as an external construction crew; the harness itself stays MCP-free and Hydra-free.

### the-verifier-agent → adopt for our /verify-equivalent hardening
- Structural independence is the reusable property: separate verifier subagent, NO shared context with the builder, read-only tools only, re-derives claims from disk (transcript/diff/tests) rather than trusting self-report.
- Bounded retry-then-escalate: `max_loops` (e.g. 3) then escalate to human — implement as a Stop-hook-triggered subagent verifier with a persisted retry counter.
- Verifier reports explicit "could not verify" gaps as a self-improvement backlog signal.

### bash-damage-from-within → adopt for PreToolUse Bash safety hook
- 5 levels of agent safety: L1 prompt instruction / L2 heavier system-prompt / L3 blacklist hook / L4 **whitelist hook** / L5 full sandboxed deny-by-default boundary.
- Thesis: L1/L2 are theatre (trust the model), L3 trusts your imagination (reactive), L4 trusts your discipline (architectural), L5 trusts only what you built (strongest).
- **Decision: build our PreToolUse Bash hook as whitelist-first (L4)** — enumerate the safe command set we actually need, deny everything else by default, rather than trying to blacklist every dangerous pattern.

### claude-code-hooks-mastery → canonical hook implementation reference (MOST reusable repo)
- Full 13-event hook lifecycle with exact JSON payloads, confirmed:
  Setup → SessionStart → UserPromptSubmit → [PreToolUse → PermissionRequest → tool exec → PostToolUse/PostToolUseFailure] → SubagentStart/SubagentStop → Notification → Stop → (loop) / PreCompact / SessionEnd.
- Exit-code contract: 0=success, 2=blocking (stderr fed back per hook-type semantics), other=non-blocking error shown to user.
- JSON control: PreToolUse `{"decision":"approve"|"block","reason":...}`; PostToolUse `{"decision":"block","reason":...}` (can't undo, just feeds back correction).
- **`stop_hook_active` guard is mandatory** on Stop/SubagentStop hooks that force continuation, to prevent infinite loops.
- File skeleton: `.claude/hooks/*.py` as `uv` single-file scripts (self-contained, no shared venv) — one per event; `validators/` subfolder for lint/type-check PostToolUse gates.
- Builder/read-only-Validator subagent pairing (`.claude/agents/team/builder.md` + `validator.md`) — lighter in-process cousin of the-verifier-agent's OS-process split; good fallback when a separate process is overkill.
- `meta-agent.md` — an agent that authors other agents; directly relevant to our own agent-factory pattern (borrowed also from AgentSmith's agent-factory-recipes).
- `ai_docs/` convention: bundle copies of Anthropic's own docs in-repo as offline grounding context for agents — worth adopting as `ai_docs/` in our harness so agents don't need network access to know their own spec.
- Status-line menu (v1-v9: git info → cost tracking → context-window usage bar → token/cache stats → powerline) — cherry-pick features.
- Output-styles presets (yaml-structured, table-based, ultra-concise, etc.) — worth offering as harness output-style options.

### bowser → four-layer composable architecture template (apply generally, not just browser)
**Skill (capability) → Subagent (scale/isolation around that capability) → Command (orchestrates many subagents, repeatable) → justfile/entrypoint (single stable calling convention).** Each layer independently testable, composes upward, can enter at any layer. Apply this template to every capability domain we build (planning, verification, review, etc.), not just browser testing.

### claude-code-hooks-multi-agent-observability → local, MCP-free telemetry sidecar
- Architecture: hook scripts → HTTP POST → local Bun server → SQLite (WAL) → WebSocket → Vue dashboard, all on localhost — Claude never talks to it directly, only plain hook scripts do (fully compatible with our no-MCP, interactive-only constraint).
- **Dual-hook-per-event wiring**: keep the functional hook (blocking/validation) and a separate telemetry-emitter hook as two independent `command` entries under the same event matcher in settings.json — observability can be added/removed without touching safety logic.
- `HookEvent` schema: `source_app`, `session_id`, `hook_event_type`, `payload`, optional `chat`, `summary` (AI-generated one-liner), `model_name` (extracted from transcript, cached), plus a built-in HITL question/permission/choice protocol over WebSocket.
- `source_app` + `session_id` dual-tagging lets one dashboard observe multiple concurrent projects/sessions — true multi-agent observability with zero MCP.
- Given our constraint is CLI-only (no persistent local dashboard mandated), we can scale this down: a lightweight local jsonl event log + a simple `pp status`-style CLI viewer command achieves the same auditability without running a server/dashboard, OR optionally offer the full local sidecar as an optional add-on for users who want a live dashboard (still no MCP, just a `just start`-style local process).

### pi-vs-claude-code / max-your-cc-sub — minor/contextual
- pi-vs-claude-code: competitive landscape only, low direct reuse (different agent runtime); the one idea (agent-to-agent comms over an out-of-band channel) resurfaces more concretely in the-verifier-agent.
- max-your-cc-sub: compliance guide, not architecture — confirms our harness is safely in the "green" zone (single-user, single-beneficiary, subscription OAuth) as long as we never route other people's requests through it or ship it as a multi-tenant service. Worth a one-line note in our own CLAUDE.md/install doc.

## Research findings — official Claude Code / Anthropic docs (COMPLETE)
(Workflow's auto-synthesis returned placeholder junk; findings below recovered directly from the research journal — all "high confidence" / verbatim-quote-confirmed against primary docs, one item explicitly refuted and corrected.)

### Core CLI mechanics
- `claude --continue` resumes most recent session in cwd; `claude --resume` opens picker; `claude --resume <session-id>` resumes by ID (scoped to cwd + its git worktrees); `claude --from-pr <n>` resumes a PR-linked session (auto-linked via `gh pr create`).
- **Plan mode**: `claude --permission-mode plan` or mid-session `Shift+Tab` — Claude reads/proposes, makes no edits until approved.
- **Worktrees**: `claude --worktree <name>` (or `-w`) creates an isolated checkout under `.claude/worktrees/<name>/` on a new branch `worktree-<name>`; run again with a different name in another terminal for a second parallel session. Configurable via a `worktree` settings object: `symlinkDirectories`, `sparsePaths`, `baseRef` (`fresh`|`head`), `bgIsolation` (`worktree`|`none` — `worktree` blocks Edit/Write in the main checkout until an `EnterWorktree` action).
- **Subagent delegation**: natural-language invocation ("use a subagent to investigate X") runs in the subagent's own context window, returns only a summary — keeps main context clean.
- **Background agents / Agent View**: run several full independent sessions in parallel, viewed from one screen (`/en/agent-view`).
- Session transcripts: JSONL at `~/.claude/projects/<project>/<session-id>.jsonl` (project = cwd path, non-alphanumerics → `-`). **Format is internal and can change between versions** — don't hand-parse; use `/export`, `claude -p --output-format json/stream-json`, hook `transcript_path`, status line, or Agent SDK instead.
- Session storage config: `CLAUDE_CONFIG_DIR` (relocate), `cleanupPeriodDays` in settings.json (default 30-day retention), `CLAUDE_CODE_SKIP_PROMPT_HISTORY` (suppress writes), `--no-session-persistence` (one-off suppress).
- Branching: `/branch`, `/rewind`, `--fork-session` — copies conversation, switches into it, original intact; **session-scoped tool-permission approvals do not carry over to the branch**.

### CLAUDE.md / memory
- `CLAUDE.md` at project root, read at start of every session — coding standards, architecture decisions, preferred libraries, review checklists.
- Hierarchical placement: `~/.claude/CLAUDE.md` (all sessions), `./CLAUDE.md` (team-shared, git), `./CLAUDE.local.md` (personal, gitignored), parent dirs (monorepo root pulled in automatically), child dirs (pulled in on-demand when Claude reads a file there).
- `@path/to/import` syntax to include other files from CLAUDE.md.
- **Auto memory** (v2.1.59+, on by default): Claude decides what's worth remembering (build commands, debugging insights, architecture notes, style prefs, workflow habits) with **no explicit user writing required**; stored at `~/.claude/projects/<project>/memory/MEMORY.md` + topic files; only first 200 lines / 25KB loaded at session start; toggle via `/memory` or `autoMemoryEnabled` setting / `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. This is a DIFFERENT, built-in mechanism from our own memory system in `C:\Users\robob\.claude\projects\...\memory\` — both exist simultaneously; harness design should treat auto-memory as a free automatic layer underneath our own curated memory files, not a replacement.

### Skills (confirmed schema)
- `SKILL.md` frontmatter: `name`, `description` (drives auto-invocation — Claude decides when relevant), optional `disable-model-invocation: true` (hides skill from Claude entirely; only manual `/skill-name` invocation; **reduces context cost to zero** since even the description doesn't load), `user-invocable: false` (inverse — Claude-only, hidden from user slash-menu), `context: fork` (runs in isolated subagent context), `allowed-tools` (pre-approve specific tools), `argument-hint`, `model`.
- By default, only name+description load at session start (low context cost); full body loads only when invoked.
- **Commands (`.claude/commands/*.md`) are the legacy predecessor to skills** — a file `deploy.md` and a skill `.claude/skills/deploy/SKILL.md` both create `/deploy` and behave the same; skills win on name conflict. **Decision: build FABLE-HARNESS entirely on `skills/`, not `commands/`**, since commands are effectively deprecated/merged.
- Dynamic context injection: `` !`command` `` syntax in a skill body runs a shell command and injects its output live.

### Subagents (confirmed schema — IMPORTANT: `model: fable` is an official alias)
- Markdown files in `.claude/agents/` (project) or `~/.claude/agents/` (user).
- Frontmatter: `name` (required, lowercase-hyphen), `description` (required — drives delegation trigger), `tools` (optional allowlist; use `skills:` field to preload skills instead), `model` (optional — **accepted values: `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit`**).
- **This confirms `fable` is a first-class, officially supported per-agent model value** — meaning our "never auto-route to Fable-5" rule must be enforced by *deliberately never writing `model: fable` into any agent/skill frontmatter that Claude can auto-invoke*, reserving it only for (a) agents that are `disable-model-invocation`/user-invoked-only, or (b) a runtime suggestion the user must explicitly accept (e.g., an AskUserQuestion-style confirmation before an agent is re-dispatched with `model: fable`).
- Subagent context on spawn = fresh/isolated: own system prompt (NOT full CC system prompt) + full content of skills listed in its `skills:` field + CLAUDE.md and git status (**except built-in Explore/Plan agents, which omit both**) + whatever the lead agent passes in the prompt.
- Resolution priority when same name exists at multiple scopes: skills = managed > user > project; subagents = managed > CLI flag > project > user > plugin. **Hooks do NOT override — all matching hooks merge and fire regardless of source.**
- Cost-control guidance (official): route cheap/routine subagent tasks to Haiku.
- **Caution (verified as an actual mischaracterization in a secondary source, corrected here)**: plain subagents do NOT coordinate with each other, do NOT share a task list, and are NOT "coordinated by a lead that assigns subtasks and merges results" in real time — that coordinating/merging behavior is a *separate, experimental, opt-in feature* (Agent Teams, below). Subagents are strictly one-shot: dispatch → isolated work → single summary back to the caller, no peer communication.

### Agent Teams (experimental, opt-in — confirmed schema)
- Disabled by default; enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json `env` block or shell environment.
- Storage: `~/.claude/teams/{team-name}/config.json` (removed at session end) and `~/.claude/tasks/{team-name}/` (persists — resumed sessions keep tasks); `team-name` = `session-` + first 8 chars of session ID.
- Teammates can be spawned from subagent definitions (project/user/plugin/CLI scope): honors that definition's `tools` allowlist and `model`; definition body is appended to (not replacing) the teammate's system prompt. **`skills:` and `mcpServers:` frontmatter fields are NOT applied when a subagent definition runs as a teammate** — teammates instead load skills/MCP from project+user settings, same as a regular session.
- Peer-to-peer coordination via shared task list/state store (not a central orchestrator) — contrast with subagents' strictly hierarchical "all through orchestrator" model.
- Three dedicated hooks for team quality gates: `TeammateIdle` (fires when a teammate is about to go idle — exit 2 to send feedback and keep it working), `TaskCreated` (exit 2 to block creation + feedback), `TaskCompleted` (exit 2 to block completion + feedback).
- Hard limitations: one team per session (no nested teams, no promoting a teammate to lead), no session resumption for in-process teammates via `/resume`/`/rewind`, no background subagents spawned from in-process teammates.
- Cost/latency reality check (secondary-source, directionally reliable): ~3-4x token cost vs. a single sequential session, 20-30s teammate startup latency, ~3x faster rate-limit consumption; practically effective team size is 2-5 agents — coordination overhead outweighs parallelism benefit beyond that unless tasks are highly isolated. **Decision: use Agent Teams sparingly** (only for genuinely-parallel, actively-communicating work), default to plain subagent delegation or the Workflow tool (pipeline/parallel) for everything else, which is cheaper and simpler.

### Hooks (confirmed authoritative schema — supersedes the ~13-event picture from secondary sources)
- **Correction**: the "31 events / cleanly 3 cadences" secondary-source claim was checked directly against the primary doc and found inaccurate — refuted. The actual official page lists **~30 distinct event names**, and the doc's own "three cadences" sentence explicitly covers only 7 of them (once per session: `SessionStart`, `SessionEnd`; once per turn: `UserPromptSubmit`, `Stop`, `StopFailure`; per tool call: `PreToolUse`, `PostToolUse`) — the rest (`Setup`, `PermissionRequest`, `PermissionDenied`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `MessageDisplay`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`) don't fit that 3-bucket framing and should just be treated as their own event names.
- **Config schema**: top-level `hooks` key in settings.json → `hooks.<EventName>[]`, each entry has `matcher` (exact string / pipe-or-comma list when only `[a-zA-Z0-9_\-, |]` chars, else unanchored JS regex — e.g. `Edit|Write`, `mcp__memory__.*`) and a `hooks[]` array of handler objects.
- **Five handler types** (`type` field, required): `command` (shell script, event JSON on stdin; fields: command/args/shell/timeout), `http` (POST to a URL; fields: url/headers/allowedEnvVars — added ~Feb 2026, needs 2xx + JSON to block, non-2xx is always non-blocking), `mcp_tool` (calls a connected MCP server tool — **not usable for us, no MCP**), `prompt` (single-turn cheap model as a policy/quality judge — **directly maps to the AI-Agent-UI-UX-Creator "prompt-type hook" pattern we want**), `agent` (experimental — spawns a subagent with Read/Grep/Glob access for the check).
- **Exit-code contract (verified precisely)**: exit 0 = success, stdout parsed as JSON. Exit 2 = blocking error, stderr fed back to Claude, **any JSON on stdout is ignored on exit 2** (only stderr matters). **Exit 1 is explicitly NOT blocking** despite being the conventional Unix failure code — this is a common gotcha; hooks meant to enforce policy MUST exit 2, not 1. Any other non-zero = non-blocking, stderr shown to user, execution continues. (One documented exception: `WorktreeCreate` aborts on ANY non-zero exit, not just 2.)
- **JSON output control**: common fields `continue` (bool), `stopReason`, `suppressOutput`. `PreToolUse` supports `hookSpecificOutput.permissionDecision` (`allow`|`deny`|`ask`|`defer`) + `permissionDecisionReason` + `updatedInput` (mutate the tool call before it runs) + `additionalContext`. `PostToolUse` supports `decision: "block"` + `reason` (can't undo the already-run tool call, just feeds Claude a correction).
- **`Stop` hook as deterministic gate**: blocks turn-ending until a check passes — but **Claude Code force-overrides after 8 consecutive blocks** to prevent a truly infinite loop; still must guard with `stop_hook_active` to avoid unnecessary recursion before that ceiling.
- Config scopes (highest → lowest precedence): managed policy (enterprise, OS-specific path e.g. `C:\Program Files\ClaudeCode\managed-settings.json`) > `.claude/settings.json` (project, shared/committable) > `.claude/settings.local.json` (project, personal/gitignored) > `~/.claude/settings.json` (user, all projects) — plus plugin `hooks.json`. Enterprise `allowManagedHooksOnly` can lock out lower scopes. `$schema` key enables IDE autocomplete/validation.
- **Permission rules** (separate from hooks but same file): `permissions.allow` / `permissions.deny` — **deny always wins, checked first**, then ask, then allow (unlisted = ask). Pattern syntax `Bash(npm run *)`, `Read(./.env*)`, `WebFetch(domain:example.com)`. **Gotcha**: `Bash(ls *)` (space before `*`) does NOT match `lsof`; `Bash(ls*)` (no space) matches both — wildcard spacing changes semantics. Compound shell commands are split on shell operators (`&&`, `|`, `;`) and each subcommand must independently match a rule. Even in `bypassPermissions` mode, `.git`, `.claude`, `.vscode` stay write-protected (with carve-outs for `.claude/commands|agents|skills`).
- Env vars of note: `CLAUDE_CODE_MAX_OUTPUT_TOKENS` (default 32K, max 64K), `MAX_THINKING_TOKENS` (default 31,999), `CLAUDE_CODE_ENABLE_TELEMETRY` + `OTEL_METRICS_EXPORTER=otlp` for observability, `apiKeyHelper` setting for dynamic credential injection (keep creds out of settings.json).

### Model-specific prompting quirks (confirmed — directly informs our model-tier table)
- **Fable 5**: no manual extended-thinking budget parameter (`budget_tokens` → 400 error) — adaptive thinking is always on, summarized-only thinking output. `effort` is the primary lever: **`high` is the recommended default**, `xhigh` for the most capability-sensitive workloads, `medium`/`low` for routine tasks. Dispatches/sustains parallel subagents more reliably than prior models — prefer async orchestrator↔subagent communication over blocking waits when using it. New `reasoning_extraction` refusal category: **never instruct it to echo/transcribe/explain its internal reasoning as response text** — this triggers refusals and elevated fallback to Opus 4.8. Has a documented `send_to_user` client-tool pattern for surfacing verbatim progress messages mid-task without ending the turn.
- **Sonnet 5**: `effort` defaults to `high`; raise to `xhigh` for the hardest coding/agentic tasks. Adaptive thinking on by default (manual `thinking.enabled`+`budget_tokens` removed, 400 error). New tokenizer produces **~30% more tokens for the same text** than Sonnet 4.6 — raise `max_tokens` limits tuned for 4.6 or risk truncation (`stop_reason: max_tokens`). Follows scope/severity-limiting instructions in review-style prompts more literally than earlier models — for review/finder agents, **decouple "find everything" from "filter for importance"** into two separate steps/prompts rather than asking it to self-filter in one pass (report everything, then a second pass ranks/filters). `temperature`/`top_p`/`top_k` set to non-default values now **return a 400 error** on Sonnet 5 (new constraint) — steer tone/style variety via system-prompt instructions, not sampling params.
- **General (all 4.6+/Fable/Mythos models)**: prefilled assistant messages on the last turn are no longer supported (400 error) — use Structured Outputs / no-preamble instructions / move continuations into the user message instead.
- **General prompting best practices**: wrap examples in `<example>` tags (`<examples>` for multiple), 3-5 examples is the sweet spot; for long-context prompts (20k+ tokens) put long documents near the top, queries at the end (up to +30% quality on complex multi-document inputs in Anthropic's own tests); for multi-session agentic coding, use git itself as a state-tracking mechanism (commits/log as checkpoints) plus structured JSON files for state and unstructured text for progress notes.

### Cross-cutting decisions this locks in for our architecture
1. **Build on `skills/`, not `commands/`** (commands are the deprecated predecessor).
2. **Model-tier table by agent role**, using the confirmed frontmatter values `sonnet`/`opus`/`haiku`/`fable`/`inherit`:
   - Haiku: cheap classifiers/routers/triage (taxonomy-mapper equivalent, judge-router equivalent, quick validators).
   - Sonnet: default workhorse — most generation/implementation/review agents.
   - Opus: highest-stakes judging, architecture, security review, synthesis/arbitration roles.
   - **Fable: NEVER written into any auto-invocable agent/skill frontmatter.** Only reachable via (a) a `disable-model-invocation: true` skill the user runs manually (e.g. `/plan-deep` invoking planning with `model: fable`), or (b) an explicit AskUserQuestion-gated suggestion flow where an agent proposes "this is complex enough that Fable-5 might do a better job — want me to re-run it with Fable?" and only proceeds on explicit yes.
3. **PreToolUse Bash hook**: whitelist-first (L4 per bash-damage-from-within), using the confirmed `hookSpecificOutput.permissionDecision` JSON contract, exit 2 to block, matcher `Bash`.
4. **Prompt-type hook** for a lightweight LLM-as-judge quality gate on Write/Edit (e.g. Haiku-model narrow check) — now confirmed as an official `type: "prompt"` hook handler, not something we have to hand-roll via `command` + a wrapper script.
5. **Stop-hook verifier gate**: implement with the confirmed `stop_hook_active` guard and awareness of the 8-consecutive-block ceiling; pair with a Task-dispatched independent verifier subagent (the-verifier-agent pattern) for the strongest version.
6. **Auto-memory coexists with our curated memory** — don't fight it, design our own memory files as the higher-signal curated layer on top of Claude's automatic one.
7. **Agent Teams used sparingly** — default to Workflow tool (pipeline/parallel, which we already have and is far cheaper/simpler and not experimental) for fan-out; reserve Agent Teams only for cases needing genuine live peer-to-peer coordination.
8. **Worktrees** for isolated parallel implementation work (matches Hydra/pair-programmer's guidance to isolate parallel candidate generation).

## Next steps
- Synthesize all three research streams (sibling repos, disler repos, official docs) into the final concrete architecture: directory layout, agent roster, skill roster, hook bindings, memory scheme, slash-skill commands, model-tier table (above), planning meta-skill, verifier subagent, safety hook, and a build sequence — then present to user via ExitPlanMode.
