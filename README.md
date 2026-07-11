# FABLE-HARNESS — User Guide

FABLE-HARNESS is an all-in-one software-development platform built **entirely from Claude
Code's native interactive-CLI primitives** — subagents, skills, hooks, memory files, the
Workflow tool, git worktrees, and plan mode. It has **no MCP servers** and never runs in
`-p`/headless mode (CONSTITUTION invariant **N8**). It is built for a single operator's own
interactive use (**N10**). Everything it produces is organized around a 16-section SDLC
taxonomy (`taxonomy_blueprint.md`), and every governance decision cites the constitution by
invariant ID.

This README is the front door. It is a map and a summary — where the governing docs
(`CONSTITUTION.md`, `AGENTS.md`, `ai_docs/model-routing-and-fable-policy.md`) are
authoritative, this file links to them rather than restating policy. When they disagree with
this file, **they win**.

---

## 1. Requirements & setup

- **Interactive Claude Code CLI only.** Use `claude`, `claude --worktree`, `claude --resume`.
  The harness never depends on `-p`/print/headless as part of its own operation (**N8**).
  Windows/PowerShell is the primary shell; the Bash tool is available for POSIX scripts.
- **`pwsh` (PowerShell 7+) must be on your PATH.** Every hook in `.claude/settings.json`
  invokes `pwsh -NoProfile` — that is PowerShell *Core* 7+, **not** the Windows-default
  `powershell` 5.1. If `pwsh` is missing, all script hooks (constitution attestation,
  bash-whitelist, fable-token-gate, verify-gate, handoff-notify) **silently no-op** under
  the fail-open rule (**N5**) — you lose your guardrails with no error message. Treat `pwsh`
  as a hard prerequisite.
- **Git.** The `verifier` and `run-finalizer` re-derive claims from `git diff` / `git log`.
  The harness assumes the working tree is a git repository; if it isn't one yet, run
  `git init` — otherwise that independent-verification substrate is degraded.
- **Optional: OpenAI Codex CLI** for cross-vendor judging. When a stage routes to
  `cross-vendor`, `judge-cross-vendor` shells out to
  `codex exec --sandbox read-only --skip-git-repo-check "<prompt>"` for a genuine equal-weight
  second opinion (**N4**). Without it, cross-vendor stages can't get their second vendor.
- **Working inside `H:\FABLE-HARNESS` needs no install** — the `.claude/` surface is already
  local to the repo.

### Installing across all your projects (optional)

`/install-user-scope` makes the harness's agents/skills/hooks available at Claude Code
**user scope** (`~/.claude`) so they work from any project directory. It is **manual-only**
and **merge-safe** — it never clobbers another project's install (**N11**). The procedure is
strict and must be followed in order:

1. **Dry run first, always:**
   `pwsh -NoProfile -File .claude\scripts\install-user-scope.ps1 -DryRun`
2. **Read the dry-run output verbatim** — it lists exactly which files convert, which per-file
   symlinks get created, and how `settings.json` merges. It flags a conflict (never
   auto-resolves) if `availableModels` already includes `fable`.
3. **Confirm explicitly** when asked.
4. **Only then apply:** `...install-user-scope.ps1 -Confirm`.

### What you'll see at session start

Every launch runs `session-start-attest`, which re-hashes `CONSTITUTION.md` and compares it
to `CONSTITUTION.sha256`. A match prints an OK banner; a mismatch prints a loud warning but
**never blocks the session** (hooks fail open, **N5**). Separately, `settings.json`
`permissions.deny` hard-blocks a few things regardless of prompt: reading `.env`/secret
files, `rm -rf`, `git push --force`, `git clean`. Full hook behavior is in [§10](#10-hooks).

---

## 2. Quick start (the 30-second version)

| You want to… | Type |
|---|---|
| Everyday planning (features, bugs, refactors) | `/plan` |
| Exceptionally deep / high-stakes planning | `/plan-deep` *(manual, Fable-5 — see §7)* |
| Run a request through the full lifecycle | `/run` |
| A focused governance-forum review of existing work | `/review <forum> <subject>` |
| Independently verify claimed work | `/verify` |
| Show / attest the constitution | `/constitution` |
| Install the harness for all projects | `/install-user-scope` *(manual)* |

**The one rule that matters most: Fable-5 is never auto-routed** (**N2**). Only *you* can
reach it, and only through `/plan-deep`. See [§6](#6-fable-5-the-manual-only-escalation).

---

## 3. The commands, in detail

### `/run` — the full lifecycle driver *(Sonnet — primary entry point)*
Runs a request through triage → profile → taxonomy → generate → judge → verify → missability
→ finalize. It mints a `run_id`, creates `.fable/<run_id>/`, writes `.fable/current-run` (so
the Stop-hook verify gate knows the active run), then invokes the real orchestration script
`Workflow({ name: "run" })`. The full walkthrough is [§4](#4-what-a-run-actually-does). Output
lands under `.fable/<run_id>/` ([§5](#5-where-everything-lives)).

### `/plan` — everyday planning *(Sonnet)*
The routine planning workhorse. Emits a self-contained **HTML** plan from the lite template
`.claude/skills/lib/plan-template-lite.html` (status-marker chips, a per-phase testing-strategy
loop, optional figure slots). Output is **run-aware**: `.fable/<run_id>/artifacts/<slug>.html`
when a run is active, otherwise **`specs/<slug>.html`** at the repo root, with a sibling
`<slug>/` image folder either way.

- **Plan images (optional).** The template's `<figure>` carries an image slot. The local,
  no-network CLI `.claude/skills/lib/plan-images.ps1` (`extract` → generate the PNG externally
  → `apply`) fills it; generated PNGs land in the sibling `<slug>/` folder. An unfilled slot
  renders as a tidy "image pending" placeholder, so the plan is fully usable without it. The
  pipeline is deliberately local-only (**N8**); never claim an image was rendered when only a
  slot exists.

### `/plan-deep` — highest-stakes planning *(Fable-5 — manual only)*
The **only** Fable-5 surface in the entire harness, gated by `disable-model-invocation: true`
(Claude can never self-invoke it). Uses the full HTML template (adds append-only metadata and
a Questionables section) and the same `plan-images` pipeline. See the approval flow in
[§6](#6-fable-5-the-manual-only-escalation). *No agent file anywhere sets `model: fable`; this
skill is the sole exception (**N2**).*

### `/review <forum> <subject>` — governance-forum review *(Sonnet)*
Runs **one of 10** standing governance forums as a focused, review-only pass over existing
work via `Workflow({ name: "review" })` — no generate-from-scratch. Each forum dispatches its
typed reviewer(s), then an independent `verifier` checks the result. Forums and their
reviewers are in [§7](#the-10-governance-forums).

### `/verify` — independent verification gate *(Sonnet)*
Dispatches the `verifier` agent, which **re-derives every claim from disk** (git diff/log,
test output, artifacts under `.fable/<run_id>/`) rather than trusting any self-report. Enforces
**Reflexion ×1** (one retry-with-critique per stage) and a **3-loop escalation ceiling**
(**N3**), and emits exactly one of three verdicts: `pass` / `pass-with-notes` / `reject`
(**N4**). This is *also* what the `Stop` hook auto-dispatches at the end of a turn, so you
rarely type it — but you can, to re-check a specific stage or claim.

### `/constitution` — show / attest governance *(Haiku)*
Prints `CONSTITUTION.md`, lists invariants N1–N11, and re-runs the SHA-256 integrity check
against `CONSTITUTION.sha256`. Also documents the amendment procedure.

### `/install-user-scope` — see [§1](#1-requirements--setup).

### Reference / internal skills
You rarely type these directly; the lifecycle and authoring flows consume them:
`taxonomy-map` (request → taxonomy sections), `model-routing` (the canonical tier + Fable
policy reference), `artifact-conventions` (where artifacts live + the 3-verdict vocabulary),
`agent-factory` (templates for authoring new agents/skills/hooks).

---

## 4. What a `/run` actually does

`/run` is a thin wrapper; the real orchestration is `.claude/workflows/run.js`. It has no
filesystem access itself — every branch decision comes from a schema-validated **typed** agent
return (**N7**), and the agents write the authoritative state to `.fable/<run_id>/*.json`. The
six phases:

1. **Setup.** `triage` classifies scope (`trivial` / `standard` / `major`, plus
   `taxonomy_floor_only`) → `profile-loader` detects the project archetype → `taxonomy-mapper`
   returns the `sections[]` to produce (applying the floor rule so even a trivial request maps
   to at least one artifact).
2. **Generate.** For each mapped section, the section's typed producer runs (the
   `SECTION_AGENT` map — [§7](#the-16-taxonomy-sections)). Sections run **pipelined** — no
   cross-section barrier.
3. **Judge.** `judge-router` picks one of two `route` values for the stage:
   - **`same-tier`** — same-vendor (Anthropic) in-house judging that itself runs **one model
     tier up**: Haiku output is judged by Sonnet, Sonnet by Opus (`run.js`). Note the label:
     `same-tier` is the literal enum value you'll see in `verdicts/` — it means *same vendor,
     next tier up*, not "the judge runs at the producer's tier."
   - **`cross-vendor`** — the OpenAI Codex bridge (`judge-cross-vendor`), for genuinely
     high-stakes / security- / concurrency- / data-integrity-flavored work or the enterprise
     profile.
4. **Verify.** The independent `verifier` re-derives the stage's claims from disk. On a
   `reject`, `reflexion-coach` bundles the critique into exactly one retry (Reflexion ×1); the
   verify gate escalates to you rather than looping past 3 total loops (**N3**).
5. **Missability.** `missability-inspector` runs a 20-item completion checklist (from
   `taxonomy_blueprint.md` §6/§10) across the run's artifacts.
   - *Best-of-N:* when scope is `major` **and** §4.8 (engineering) is in the map, N `engineer`
     candidates are generated in isolated git worktrees and `oracle-evaluator` picks a winner
     by Borda count before this phase.
6. **Finalize.** `run-finalizer` patches the project's `PROJECT_MASTER.md`, writes the run
   summary, archives best-of-N losers, and appends the outcome to `.fable/runs.jsonl`.

**Outcome:** the run is **`finalized`** only if the finalizer's own disk-based check passes.
If any stage is still `reject` **or** missability fails, the run is **`surfaced`** instead
(finalize is skipped) — see [§11](#11-troubleshooting--reading-a-surfaced-outcome).

---

## 5. Where everything lives

Per-run state is **gitignored** under `.fable/<run_id>/`:

```
.fable/
  current-run                 # the active run_id (Stop-hook verify gate reads this)
  runs.jsonl                  # append-only ledger of finished runs
  fable-approval.token        # single-use Fable-5 authorization (see §6)
  <run_id>/
    run.json                  # run metadata
    taxonomy_map.json         # which of the 16 sections this run produces
    artifacts/<section>-<kind>.md   # e.g. 4.7-openapi.md
    stages/<stage>.json       # Reflexion state per stage
    verdicts/<stage>.json     # judge/verifier verdicts
    telemetry.jsonl
    handoffs/*.json           # file-mediated cross-session coordination (§10)
```

- **`run_id` format:** `/run` mints `yyyyMMdd-HHmmss-<slug>` (e.g.
  `20260710-183000-add-auth-endpoint`), per `.claude/skills/run/SKILL.md`. *(Heads-up: an
  example in `artifact-conventions/SKILL.md` shows a different `run-2026-07-10-abc123` style —
  the `run/SKILL.md` form is the one actually minted and is canonical.)*
- **Plans** land in `.fable/<run_id>/artifacts/<slug>.html` when a run is active, else
  **`specs/<slug>.html`** at the repo root.
- **Two memory layers.** Claude's own **auto-memory** (`~/.claude/projects/.../MEMORY.md`) is
  automatic and low-signal — left on. The repo's **`memory/`** directory (committed:
  `decisions/`, `invariants.md`, `glossary.md`) is the curated, high-signal, **authoritative**
  layer. When the two disagree, `memory/` wins.

---

## 6. Fable-5: the manual-only escalation

Fable-5 is the highest-capability, highest-cost model tier, and it is **never auto-routed**
(**N2**). There are exactly two opt-in paths:

- **You type `/plan-deep` directly.** Your invocation *is* the approval — it proceeds
  unconditionally, no token needed.
- **An agent suggests it.** If an agent judges a task Fable-worthy, it must ask you via
  `AskUserQuestion` in a normal conversational turn (never inside a `Workflow()` — dynamic
  workflows have no mid-run human input). Only an explicit "yes" writes a single-use
  `.fable/fable-approval.token`, and only then may a **freshly invoked** `/plan-deep` proceed
  and consume it. A "no" never writes the token.

**Why it can't leak.** The policy is a **six-surface** enforcement story (per
`CONSTITUTION.md` and `ai_docs/model-routing-and-fable-policy.md`). Six are model-*selection*
surfaces — subagent frontmatter `model:`; a per-invocation Task `model` param;
`CLAUDE_CODE_SUBAGENT_MODEL`; `/model`; `/advisor` (`advisorModel`); `teammateDefaultModel` —
and the seventh entry, **`availableModels`, is the structural *gate* over all of them**:
`.claude/settings.json` excludes Fable from the available pool, so none of the six selection
surfaces can silently pick it ("if Fable isn't in the available set, none of surfaces 1–6 can
silently select it"). A `UserPromptSubmit` hook additionally denies `/model fable` and
`/advisor`→Fable switches unless the approval token exists. Full detail:
[`ai_docs/model-routing-and-fable-policy.md`](ai_docs/model-routing-and-fable-policy.md).

---

## 7. Reference

### Model tiers

Haiku, Sonnet, and Opus are **freely auto-routed**; Fable-5 is **manual-only** (`/plan-deep`).
Use the exact per-agent tiers below — do not assume "all producers are Sonnet."

- **Opus (exactly 6):** `judge-cross-vendor`, `verifier`, `meta-agent`, `strategy-author`,
  `architect`, `security-reviewer`.
- **Haiku (exactly 7):** `triage`, `profile-loader`, `taxonomy-mapper`, `judge-router`,
  `missability-inspector`, `docs-author`, `visual-regression-runner`.
- **Sonnet:** every other agent (the default workhorse tier).

### The 16 taxonomy sections

Each section's owning producer is from `run.js`'s `SECTION_AGENT` map. **§4.14 has no dedicated
producer** — it falls to the `docs-author` default.

| § | Section | Producer |
|---|---|---|
| 4.1 | Strategy, business context, and investment logic | `strategy-author` |
| 4.2 | User, market, workflow, and domain understanding | `discovery-researcher` |
| 4.3 | Product scope, requirements, and prioritization | `spec-author` |
| 4.4 | Experience design, content, and accessibility | `designer` |
| 4.5 | Domain model, data, analytics, and information lifecycle | `data-modeler` |
| 4.6 | Architecture and technical strategy | `architect` |
| 4.7 | Interfaces, contracts, and integration wiring | `api-designer` |
| 4.8 | Engineering implementation system and code quality | `engineer` |
| 4.9 | Security, privacy, compliance, and trust | `security-reviewer` |
| 4.10 | Quality engineering and verification | `test-strategist` |
| 4.11 | Delivery, environments, release, and change management | `release-planner` |
| 4.12 | Observability, reliability, operations, and support | `ops-author` |
| 4.13 | Documentation, enablement, and knowledge management | `docs-author` |
| 4.14 | Team operating model, decision governance, and execution cadence | *(no dedicated producer → `docs-author` default)* |
| 4.15 | AI and agentic system controls | `ai-controls-author` |
| 4.16 | Deprecation, retirement, and lifecycle exit | `retirement-planner` |

### The 10 governance forums

From `review.js`'s `FORUM_AGENTS` (used by `/review <forum>`):

| Forum | Reviewer agent(s) |
|---|---|
| `discovery` | `discovery-researcher`, `strategy-author` |
| `scope` | `spec-author` |
| `design` | `designer`, `design-system-curator` |
| `architecture` | `architect` |
| `api_contract` | `api-designer` |
| `threat_privacy` | `security-reviewer` |
| `test_readiness` | `test-strategist` |
| `release_readiness` | `release-planner` |
| `incident_postmortem` | `ops-author` |
| `service_review` | `ops-author`, `governance-author` |

### The 32 agents

Tier column uses the real `ai_docs/model-routing-and-fable-policy.md` values.

| Agent | Tier | Role |
|---|---|---|
| `triage` | Haiku | First-touch scope classifier (trivial/standard/major) |
| `profile-loader` | Haiku | Detects the project archetype from repo signals |
| `taxonomy-mapper` | Haiku | Maps a request to the 16 taxonomy sections (with floor rule) |
| `judge-router` | Haiku | Picks same-tier vs cross-vendor judging for a stage |
| `docs-author` | Haiku | Changelogs, release notes, runbooks, docs; the trivial-scope floor producer |
| `missability-inspector` | Haiku | Runs the 20-item completion checklist over a run |
| `visual-regression-runner` | Haiku | Before/after UI screenshot diffs (UI profiles; skips otherwise) |
| `judge-cross-vendor` | Opus | Equal-weight second opinion via OpenAI Codex CLI |
| `verifier` | Opus | Independent, read-only re-derivation of claimed work from disk |
| `meta-agent` | Opus | Authors new agents/skills/hooks (the harness's self-extension) |
| `strategy-author` | Opus | §4.1 vision/business case/OKRs/kill-criteria |
| `architect` | Opus | §4.6 C4 diagrams, ADRs, tech-stack, deployment (text/Mermaid only) |
| `security-reviewer` | Opus | §4.9 threat model, privacy, auth, control matrix, SBOM |
| `spec-author` | Sonnet | §4.3 PRDs, specs, acceptance criteria (RFC-2119) |
| `engineer` | Sonnet | §4.8 the only code-writing producer |
| `api-designer` | Sonnet | §4.7 OpenAPI 3.1 / AsyncAPI 3 contracts, versioning |
| `data-modeler` | Sonnet | §4.5 domain model, ERD, data dictionary, lineage, retention |
| `test-strategist` | Sonnet | §4.10 test strategy, contract/E2E tests, perf/a11y budgets |
| `release-planner` | Sonnet | §4.11 rollout/rollback, migration runbook, feature flags |
| `ops-author` | Sonnet | §4.12 SLIs/SLOs, telemetry, dashboards, runbooks, incidents |
| `ai-controls-author` | Sonnet | §4.15 eval suite, guardrail policy, tool-permission matrix, HITL |
| `retirement-planner` | Sonnet | §4.16 deprecation, EOL, migration/shutdown plans |
| `discovery-researcher` | Sonnet | §4.2 research briefs, personas, JTBD, journey maps, glossary |
| `designer` | Sonnet | §4.4 IA maps, user flows, 8 canonical states, wireframes (text) |
| `design-system-curator` | Sonnet | Design tokens + component specs (the `design` forum) |
| `reflexion-coach` | Sonnet | Bundles a failing verdict + critique into the single retry |
| `oracle-evaluator` | Sonnet | Best-of-N Borda-count comparison across worktree candidates |
| `master-plan-patcher` | Sonnet | Patches `PROJECT_MASTER.md` after a run finalizes |
| `run-finalizer` | Sonnet | Last agent in a run: summary, ledger, master-plan patch |
| `agents-md-author` | Sonnet | Keeps `AGENTS.md` in sync (never edits `CLAUDE.md` for content) |
| `governance-author` | Sonnet | RACI, decision logs, forum outputs (the `service_review` forum) |
| `browser-validator` | Sonnet | Live E2E validation in a real browser (UI profiles; skips otherwise) |

### Judge rubrics (`.claude/rubrics/`)

| Rubric | Aligns with |
|---|---|
| `rfc-2119` | §4.3 spec / `scope` forum (normative MUST/SHOULD language) |
| `c4` | §4.6 architecture / `architecture` forum |
| `openapi-3.1` | §4.7 contracts / `api_contract` forum |
| `owasp-asvs` | §4.9 security / `threat_privacy` forum |
| `wcag-2.2` | §4.4 accessibility / `design` forum |

### Project profiles (`.claude/profiles/`)

Exactly four archetypes exist: **`web-ui`**, **`api`**, **`cli`**, **`ai-agentic`**.
`profile-loader` detects which one applies from repo signals; the profile parameterizes design
dials and judging strictness. *(There is no `enterprise.yaml` — "enterprise" appears in prose
as an archetype concept but is not a shipped profile file.)*

### The 11 invariants (`CONSTITUTION.md`)

- **N1** Constitution integrity — the file is the single source of truth; changes require
  regenerating `CONSTITUTION.sha256` + a decision record.
- **N2** Fable-5 is manual-only, never auto-routed (`/plan-deep` is the sole surface).
- **N3** Reflexion ×1 and bounded retry-then-escalate (3-loop verify ceiling).
- **N4** Fail-closed validation, three verdicts only (`pass` / `pass-with-notes` / `reject`);
  a validator that can't validate returns `reject`.
- **N5** Hooks fail *open* on internal bug (`exit 0`), fail *closed* on policy violation
  (`exit 2`, never `exit 1`).
- **N6** Whitelist-first shell safety — the Bash hook allows only an explicit allow-set.
- **N7** Typed-agent provenance — never substitute a generic agent for a typed producer.
- **N8** No MCP, no headless — interactive CLI only.
- **N9** Preserved-Invariants contract on revision — list Preserved vs Changed, halt on
  contradiction.
- **N10** Single-user scope.
- **N11** User-scope install never clobbers.

**Precedence:** N1 > N2 > N4 > N3 > N5 > N6 > N7 > N8 > N9 > N10 > N11 (N2 and N4 always win
over everything except N1). When an agent or hook refuses or downgrades a verdict, it cites the
reason in the greppable form `Refused per N<k>: <short reason>`.

### Glossary (`memory/glossary.md`)

- **Run** — one invocation of `/run`, tracked under `.fable/<run_id>/`.
- **Stage** — one step of a run's lifecycle (generate → judge → verify → missability → finalize).
- **Verdict** — a judge/verifier outcome: `pass` | `pass-with-notes` | `reject` (**N4**).
- **Reflexion** — a bounded, single retry-with-critique for a failed stage (**N3**).
- **Taxonomy floor** — the minimum artifact (e.g. a changelog entry) every request produces.
- **Fable-approval token** — the single-use `.fable/fable-approval.token` gating Fable-5 (**N2**).
- **Handoff envelope** — a JSON file under `.fable/<run_id>/handoffs/` for file-mediated
  cross-session coordination.

---

## 8. Directory layout

```
CONSTITUTION.md / CONSTITUTION.sha256   governance root + integrity hash (N1)
AGENTS.md / CLAUDE.md                    cross-tool contract / Claude-specific shim
README.md                                this guide
plan.md                                  the build plan / known limitations
taxonomy_blueprint.md                    the 16-section SDLC taxonomy
.claude/
  agents/      32 typed producer/governance subagents
  skills/      11 skills (SKILL.md each) — the user-facing surface
    lib/       shared plan templates + the local plan-images CLI
  workflows/   run.js, review.js — the real Workflow-tool orchestration scripts
  hooks/       hook scripts (.ps1 + .sh mirror), all fail-open (N5)
  team-configs/ plain YAML data read by workflows (not a primitive)
  rubrics/     5 judge rubrics
  profiles/    4 project-archetype profiles
  scripts/     install-user-scope.ps1
  settings.json  hooks + permissions + availableModels (the primary Fable gate)
ai_docs/       offline grounding copies of Claude Code mechanics + model policy
memory/        curated, committed memory (decisions/, invariants.md, glossary.md)
specs/         top-level plan output when no run is active
.fable/        gitignored per-run state (see §5)
```

---

## 9. Cross-session, worktrees & Agent Teams

Three coordination mechanisms, in increasing exoticism (see `AGENTS.md` "Multi-agent
systems"):

1. **Hierarchical subagents (default).** The Workflow scripts fan out **typed** producer
   agents (**N7**). This is the normal path and needs nothing special from you.
2. **Agent Teams (experimental, opt-in).** For genuinely live, actively-communicating parallel
   work in one session. Constraints: a teammate can't become a lead and can't spawn a nested
   team. Default to plain subagents/Workflow fan-out unless you specifically need live teamwork.
3. **File-mediated cross-session handoffs.** There is no native "team-lead-to-team-lead"
   primitive. When multiple `claude --worktree` sessions each run their own work, they
   coordinate by reading/writing shared JSON envelopes under `.fable/<run_id>/handoffs/`. This
   is **async, disk-based coordination — not a real-time message bus**; never assume a message
   crossed sessions instantly. The `PostToolUse:Write` → `handoff-notify` hook ([§10](#10-hooks))
   is what nudges this along.

---

## 10. Hooks (the automatic behaviors you never type)

Wired in `.claude/settings.json`, scripts in `.claude/hooks/`. The *script* hooks are each a
`.ps1` with a `.sh` mirror; the `PreToolUse:Edit|Write` one is an **inline `type: prompt`
Haiku hook with no script file**.

| Event | Hook | What it does |
|---|---|---|
| `SessionStart` | `session-start-attest` | The startup banner — re-hashes the constitution vs `CONSTITUTION.sha256` |
| `UserPromptSubmit` | `fable-token-gate` | Denies `/model fable` / `/advisor`→Fable unless the approval token exists |
| `PreToolUse:Bash` | `bash-whitelist` | Whitelist-first shell safety (**N6**) — anything not on the allow-set is denied |
| `PreToolUse:Edit\|Write` | *(inline Haiku prompt)* | Blocks placeholder/AI-tell/secret debris from being written |
| `Stop` | `stop-verify-gate` | Auto-dispatches the `verifier` — the mechanism by which `/run` reaches `surfaced` |
| `PostToolUse:Write` | `handoff-notify` | Drives the cross-session handoff model ([§9](#9-cross-session-worktrees--agent-teams)) |

**Posture (N5/N6):** a *bug* inside a hook must `exit 0` (fail open — a broken hook must not
brick the session). A genuine *policy violation* the hook is designed to catch must `exit 2`
(fail closed — note: `exit 1` is non-blocking in Claude Code and is a common accidental-bypass
gotcha).

---

## 11. Troubleshooting & reading a `surfaced` outcome

- **A run came back `surfaced`, not `finalized`.** That means a stage is still `reject` or the
  missability checklist failed, so finalize was skipped. Look in `.fable/<run_id>/verdicts/<stage>.json`
  (the verdict + notes) and `.fable/<run_id>/stages/<stage>.json` (Reflexion state). Fix the
  underlying artifact, then re-drive with `/verify` (to re-check) or `/run` again.
- **Retries seem capped.** They are: Reflexion allows **one** retry-with-critique per stage, and
  the verify gate escalates to you after **3** total loops rather than looping forever (**N3**).
  Escalation is the intended terminal state, not a failure of the harness.
- **Something got refused.** Search the output for `Refused per N<k>:` — every governance
  refusal cites the exact invariant and a short reason, so you can look it up in
  [§7](#the-11-invariants-constitutionmd) or `CONSTITUTION.md`.
- **Hooks aren't firing / guardrails feel absent.** Confirm `pwsh` (PowerShell 7+) is on your
  PATH — missing `pwsh` makes every script hook silently no-op under fail-open ([§1](#1-requirements--setup)).

---

## 12. Where to go deeper

- **`AGENTS.md`** — the full cross-tool behavioral contract (layout, multi-agent rules,
  engineering standards). `CLAUDE.md` is a thin `@AGENTS.md` shim.
- **`CONSTITUTION.md`** — the governance root and the authoritative text of N1–N11.
- **`ai_docs/model-routing-and-fable-policy.md`** — the canonical model-tier table and the full
  Fable-5 enforcement story.
- **`taxonomy_blueprint.md`** — the 16-section SDLC taxonomy the harness is organized around.
  *Caveat:* its §13 describes a "game-dev profile family," engine sub-modes, and ~10 game-dev
  rubric IDs (`game-perf-budget@1`, `console-cert-checklist@1`, `steam-ai-disclosure@1`, …) that
  are **not implemented on disk** — only the 4 profiles and 5 rubrics in [§7](#7-reference)
  actually exist. Don't chase those.
- **`plan.md`** — the build record: design rationale, full inventory, and known limitations.

---

## 13. Sibling projects

FABLE-HARNESS builds *other* projects as separate, independent git repositories — it never
nests another project's tree inside its own. The `mythic-proportion/` directory visible in this
checkout is one such sibling: it is its **own** git repo with its own `main` branch and history,
excluded from FABLE-HARNESS's `.gitignore` so the two trees never entangle.

- **mythic-proportion** — an LLM-Wiki "second brain" app (drop-folder ingest → LLM-compiled
  Markdown wiki → hybrid BM25+vector search → an in-progress 3D GraphRAG rebuild). Repo:
  `https://github.com/lebobo88/mythic-proportion` (placeholder — not yet pushed; local-only at
  time of writing). See `mythic-proportion/README.md` and `mythic-proportion/specs/` for its own
  roadmap and grounding docs.
