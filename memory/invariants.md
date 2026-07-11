# Preserved Invariants Ledger

Append-only. Each entry records a behavior that a later revision must not silently break (per CONSTITUTION.md N9). Format: `- **<artifact/area>**: <invariant> (recorded <date>, by <agent>)`.

- **plan-deep/SKILL.md**: remains the ONLY file in the harness that sets `model: fable`, still gated by `disable-model-invocation: true`; the Step-0 approval-token flow is unchanged. A later revision must not add a second Fable surface or weaken this gate (N2). (recorded 2026-07-10, by plan-html-switch)
- **plan-deep + plan HTML templates**: every planf3 template section must remain present (Metadata, Purpose/Problem/Solution, Relevant files, Implementation phases each with a Testing-strategy loop, Global validation, Questionables, Notes, Amendments for the full template); the `<details class="meta">` metadata and the Amendments section stay append-only; status vocabulary is fixed at `[] / [wip] / [x] / [f]`. (recorded 2026-07-10, by plan-html-switch)
- **plan image pipeline (.claude/skills/lib/plan-images.*)**: must stay a local CLI only — no network, no MCP, no model/API call — so the harness's own operation never depends on MCP/headless (N8). Auto-generation, if added later, must remain an explicitly opt-in local subcommand. (recorded 2026-07-10, by plan-html-switch)
- **designer agent**: renders no product-UI pixels — wireframes are text/markdown only. The separate plan-diagram image pipeline does not change this; designer must not claim to produce UI mockups. (recorded 2026-07-10, by designer-revision)
