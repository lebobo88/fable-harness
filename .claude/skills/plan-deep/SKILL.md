---
name: plan-deep
description: Highest-stakes planning skill using Fable-5. Manual-only — Claude can never auto-invoke this; only a user typing /plan-deep can. Use for the small number of asks big enough to warrant Fable-level structure and thinking budget (major-scope architecture, cross-cutting rewrites, irreversible decisions).
disable-model-invocation: true
model: fable
---

# /plan-deep — Fable-5 deep planning

This is **the only file in the entire FABLE-HARNESS repo that sets `model: fable`** (CONSTITUTION.md N2). It is reachable exclusively via a user directly typing `/plan-deep` — `disable-model-invocation: true` means Claude can never auto-invoke it, and no other agent/skill in this harness is permitted to reference or trigger it programmatically.

## Step 0 — the approval-token gate (do this before anything else)

Before writing a single line of plan content, check whether `.fable/fable-approval.token` exists.

- **If this skill was invoked because the user directly typed `/plan-deep` in this turn:** proceed immediately regardless of whether the token exists. The user typing the command IS the approval — direct invocation never needs a token. Do not mention the token to the user in this case; it is irrelevant to the manual path.
- **If you have any reason to believe this skill is running because some other agent, skill, or workflow step *suggested* running it** (e.g. you are resuming a context where a prior turn said "this looks Fable-worthy, want me to run /plan-deep?"): check for `.fable/fable-approval.token`.
  - If it exists and is unconsumed: proceed, then delete/consume the token (single-use) once the plan file is created.
  - If it does **not** exist: STOP. Do not proceed with Fable. Explain to the user, in plain terms: "Direct `/plan-deep` invocation is always allowed — but this looked like it was reached via an agent's suggestion rather than you typing the command yourself. Per the harness's Fable-5 policy (see `ai_docs/model-routing-and-fable-policy.md`), an agent-suggested path to Fable requires an explicit `AskUserQuestion` confirmation first, which writes a single-use approval token. That hasn't happened yet." Then ask the user directly whether they want to proceed (i.e. give them the AskUserQuestion they're owed), and only continue once they say yes and the harness writes the token, or once they simply retype `/plan-deep` themselves (which is direct invocation and needs no token at all).

In short: **direct user invocation is always sufficient, unconditionally — the token only exists to gate the agent-suggested path.** See `model-routing` skill and `ai_docs/model-routing-and-fable-policy.md` for the full six-surface enforcement story this token is one piece of.

## What this skill produces

A single self-contained **HTML** plan file in the planf3 ("Plans For Fable 5") style this skill is named after. Build it from the shared template and design system at **`.claude/skills/lib/plan-template.html`** — copy that file to the output location and fill every `«placeholder»`; do not reinvent the markup or the embedded CSS.

**Output location (run-aware):**
- If a run is active (`.fable/<run_id>/run.json` exists) → `.fable/<run_id>/artifacts/<slug>.html`, with a sibling image folder `.fable/<run_id>/artifacts/<slug>/`.
- Otherwise → `specs/<slug>.html` in the repo root, with a sibling `specs/<slug>/`.
- `<slug>` is a short kebab-case name derived from the plan title.

The template is load-bearing — **every section must appear**: Metadata, Purpose, Problem, Solution, Relevant files, Implementation phases (each with its Testing-strategy loop), Global validation commands, Questionables, Notes, Amendments. Do not compress it into prose or drop sections. Repeat the `.phase` block once per phase, bumping the number and the image basename.

### Images — manual-first, N8-safe

The template carries **image slots**, not images. Each `<figure>` holds one slot comment —
`<!-- {{...IMAGE: <basename> | <subject sentence>}} -->` — plus a graceful "image pending" placeholder and an always-present `<figcaption>`, so **the plan is fully usable with zero images**. Fill a concrete `<subject>` for every slot (hero / problem / solution / phaseN / notes) and write a real caption.

Image generation is **manual** — this harness calls no image API (CONSTITUTION.md N8). The workflow:
1. `pwsh .claude/skills/lib/plan-images.ps1 extract <plan>.html` → writes `<slug>.image-prompts.md`, one copy-paste prompt per figure (subject + the universal 1536×1024 style spec + target path).
2. Generate the PNGs in any external image tool **when API credits allow** — as many or as few as you want — saving each to `<slug>/<basename>.png`.
3. `pwsh .claude/skills/lib/plan-images.ps1 apply <plan>.html` → swaps each slot whose PNG now exists for an `<img>`; the placeholder auto-hides via CSS. Idempotent — re-run as you add more.

Surface the prompt sheet to the user so they can generate images themselves; **never claim images were rendered when only slots/prompts exist.** Full workflow in `.claude/skills/lib/README.md`.

### Live status + append-only discipline

- Status markers stay `[]` idle / `[wip]` in progress / `[x]` done / `[f]` failed — rendered as `<code class="status" data-st="…">` chips, flipped live on disk as work proceeds. `[f]` is the explicit escape hatch: do not leave a phase silently stuck; mark it `[f]` and record why in Notes rather than looping forever.
- The `<details class="meta">` block is **append-only** — add a new `<dd>` under `modified`/`commits`, never edit prior lines.
- The `<section id="amendments">` block is **append-only** — entries newest-at-bottom, never rewrite history. This is the N9 mechanism whenever a plan revises an earlier one.
- Keep the Questionables section always visible; if nothing is open, state "None currently open" rather than omitting it.
- The Testing-strategy loop inside each phase is mandatory: run checks → fix → re-run; do not advance until every check passes (or the phase is honestly marked `[f]`). Global validation commands are the final gate after all phases show `[x]`.

## Preserved Invariants vs Changed Behaviors (CONSTITUTION.md N9)

This skill was revised from Markdown output to HTML + image slots. Per N9:

**Preserved invariants (must not break):**
- Remains the **only** file in the harness with `model: fable`; `disable-model-invocation: true` still gates it (N2).
- Step 0 approval-token gate is unchanged.
- Every prior template section still appears (metadata, phases, per-phase testing loop, global validation, Questionables, Notes, Amendments).
- Status-marker vocabulary `[] / [wip] / [x] / [f]` is unchanged.
- Metadata and Amendments remain append-only.
- No network/MCP dependency is introduced — the image pipeline is a local CLI only (N8).

**Changed behaviors:**
- Output format Markdown → self-contained HTML (shared template `.claude/skills/lib/plan-template.html`).
- Plans now carry `<figure>` image slots + a manual `extract`/`apply` image pipeline (`.claude/skills/lib/plan-images.ps1`, `.sh` mirror).
- Default output path is now run-aware (`.fable/<run_id>/artifacts/` or top-level `specs/`).

## Fable-5 prompting notes for this skill specifically

Per `ai_docs/model-routing-and-fable-policy.md`: use `effort: high` by default (raise to `xhigh` only for the most capability-sensitive plans); never ask Fable to echo/transcribe its own internal reasoning as response text (triggers a `reasoning_extraction` refusal and elevated Opus 4.8 fallback); prefer async orchestrator↔subagent communication over blocking waits if this plan dispatches parallel subagents; there is no manual thinking-budget parameter, adaptive thinking is always on.

## Constitution citations

This skill exists to satisfy N2 (Fable-5 manual-only) precisely — it is the single sanctioned entrypoint. It also upholds N9 (Preserved-Invariants-vs-Changed-Behaviors) whenever a plan revises an earlier one: use the Amendments section for that, never silently rewrite prior phases. The image pipeline is local-CLI-only, upholding N8 (no MCP, no network as part of the harness's own operation).
