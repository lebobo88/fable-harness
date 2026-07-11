---
name: plan
description: Everyday, auto-invocable planning skill for routine feature/bug/refactor work. Sonnet-tier — the non-Fable default. Use for most planning needs; escalate to /plan-deep (manual-only, Fable-5) only for the rare highest-stakes plan.
model: sonnet
---

# /plan — everyday planning

The routine planning workhorse. It emits the same self-contained **HTML** plan format as `plan-deep`, but from the lighter shared template `.claude/skills/lib/plan-template-lite.html` — keeping status-marker chips, a per-phase testing-strategy loop, and optional image slots, while dropping the append-only-metadata `<details>` ceremony and the Questionables section (those are reserved for `plan-deep`'s highest-stakes plans; CONSTITUTION.md N2 scopes Fable-5 to that one skill only — this skill never sets `model: fable` and never will).

## When to use this vs. plan-deep

- Use `plan` (this skill, auto-invocable) for: standard features, bug fixes, refactors, most of what a `/pp:run`-style pipeline or ordinary conversational planning needs.
- Suggest `plan-deep` only when a task is genuinely major-scope, irreversible, or cross-cutting enough to warrant Fable-5's extra structure/thinking budget — and even then, per N2, you must use `AskUserQuestion` to get explicit approval before any Fable path proceeds (see the `model-routing` skill). Never invoke `/plan-deep` yourself; only the user can.

## Template & output

Build the plan from the lighter shared template **`.claude/skills/lib/plan-template-lite.html`** — copy it to the output location and fill every `«placeholder»`. Same self-contained HTML + embedded design system as `plan-deep`, minus the metadata/Questionables ceremony.

**Output location (run-aware):** `.fable/<run_id>/artifacts/<slug>.html` when a run is active, else `specs/<slug>.html` in the repo root; sibling `<slug>/` image folder either way. `<slug>` is a short kebab-case name from the plan title.

Keep every structural piece the lite template ships: the status legend, an Overview, one `.phase` block per phase (each with its Testing-strategy loop and its `[f]` escape hatch), and Notes. Repeat the `.phase` block per phase, updating the status chips live on disk.

**Images are optional for lite plans.** The template's `<figure>` carries a `<!-- {{...IMAGE: hero | … }} -->` slot; if you want a diagram, fill the subject and use the same manual pipeline as `plan-deep` (`plan-images.ps1 extract` → generate the PNG externally when credits allow → `apply`). A slot left ungenerated renders as a tidy "image pending" placeholder, so the plan is fully usable without it. Never claim an image was rendered when only a slot/prompt exists.

## Preserved Invariants vs Changed Behaviors (CONSTITUTION.md N9)

Revised from Markdown output to HTML. **Preserved:** status vocabulary `[] / [wip] / [x] / [f]`; the per-phase testing-strategy loop and its `[f]` escape hatch; `model: sonnet` (never `fable`, N2); still lighter than `plan-deep` (no metadata/Questionables ceremony). **Changed:** output format Markdown → self-contained HTML (`.claude/skills/lib/plan-template-lite.html`); optional `<figure>` image slots + the manual `plan-images` pipeline; run-aware output path.

## Guidance

- Keep phases small enough that each Testing Strategy loop is genuinely checkable — a phase with no verifiable exit condition is a sign it should be split.
- Update status markers live, on disk, as work proceeds — don't let them go stale relative to actual progress.
- If you notice a plan created with this skill is turning out to need append-only audit history, a Questionables toggle, or genuinely wants Fable's extra reasoning budget, say so explicitly and let the user decide whether to restart it under `/plan-deep` instead of retrofitting the lightweight template.
