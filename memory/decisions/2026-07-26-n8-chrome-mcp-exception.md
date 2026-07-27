# Decision — N8 narrow exception for `claude-in-chrome` MCP consumption

- **Date:** 2026-07-26
- **Status:** accepted
- **Authority:** operator, explicit approval in session `65320b6a-67b8-4aae-b9f8-39e614f3fc61`
- **Amends:** `CONSTITUTION.md` N8 (hash regenerated in the same change, per N1)
- **Related:** `memory/invariants.md` entries dated 2026-07-26; runs `20260726-213456-p1-render-foundation`, `20260726-221514-p1-black-frame-fix`, `20260726-225631-p1-render-loop-and-lighting`

## Context

FABLE-HARNESS was scoped for software delivery generally and never for game or
graphics work specifically. SOLAR FRONTIER (a browser game built on three.js /
React Three Fiber, planned via `/plan-deep` into `specs/solar-frontier.html`) is the
first project to exercise rendering work through the lifecycle, and it exposed a
structural gap immediately.

Run `20260726-213456-p1-render-foundation` produced a Phase 1 renderer that passed
**typecheck, lint, 25/25 unit tests, production build and the bundle-size budget** —
and rendered a **completely black screen**. The scene's camera framing and sun
placement had never been reconciled, putting the sun ~53° outside a 50° frustum, which
made the `GodRays` effect raymarch from an off-screen source and black out the entire
composite. The stage returned `pass-with-notes`.

That verdict was not negligence by any agent. It was structurally unavoidable: under
the previous reading of N8, **no agent in this harness could open a browser**, so no
agent could ever distinguish "renders correctly" from "renders black". Every visual
claim had to be either fabricated or routed through the operator by hand.

## Decision

Amend N8 to permit agents to list `mcp__claude-in-chrome__*` tools in their allowlist,
for the sole purpose of **observing a locally-served page** — screenshots, console and
network reads, JS evaluation, frame-time sampling.

### Why this does not violate N8's intent

N8's actual prohibition is that FABLE-HARNESS *"never registers an MCP server"* and
*"never depends on `-p`/print/headless invocation as part of its own operation."* Both
hold unchanged:

- **Registers nothing.** This repo ships no `.mcp.json` and starts no server. The
  browser MCP is provided by the operator's own interactive Claude Code session. We are
  a *consumer* of an already-present capability, not a publisher of one.
- **Creates no dependency.** The exception is explicitly non-load-bearing. Any agent
  using it MUST detect absence and degrade to an explicit `unverified` report. The
  harness continues to function, and every run still completes, on a machine where the
  browser MCP is not installed.

The stricter phrasing in `AGENTS.md` — *"no MCP tool names anywhere in this repo"* — was
a house convention that read more broadly than N8 itself. It has been corrected in the
same change so the repo does not contradict its own constitution.

### Boundaries

- **Only** the `mcp__claude-in-chrome__*` namespace. No other MCP namespace may appear
  in any agent allowlist, notwithstanding that this operator's session also exposes
  `blender`, `deepseek-pi`, `atelier` and others.
- **Only** for observing a locally-served page. This is not general web browsing.
- **N4 still governs the verdict.** A validator that cannot validate returns `reject`,
  never silence and never an optimistic pass.

## Alternatives considered

- **Leave N8 as-is; operator verifies everything by hand.** This is what happened for
  three consecutive runs. It works, and it is the fallback whenever the browser MCP is
  absent, but it means the lifecycle cannot self-verify its most important claim about
  any visual change, and it puts the operator in the verification loop for every
  iteration.
- **Allow any session-registered MCP.** Rejected as too broad. It would admit
  `blender`, ComfyUI and ElevenLabs into agent allowlists by default and would erode N8
  to the point where its remaining content is only "we don't ship a daemon."
- **Adopt `pair-programmer`'s MCP-backed harness wholesale.** Rejected: it registers
  three stdio daemon servers (`pp_harness`, `pp_codex`, `pp_gemini`), which N8 prohibits
  outright and which this decision does not disturb.

## Consequences

- A future `browser-validator` (or a revision of the existing one) may genuinely drive a
  browser rather than shelling out. Authoring that agent is **not** part of this
  decision and is deferred to the Tier 2 harness-extension run.
- Perf and visual claims gain a real evidence path, which the new
  `.claude/rubrics/game-perf-budget.md` rubric now requires.
- Until such an agent exists, the operator remains the only party who can confirm a
  rendered frame, and producers must keep reporting visual/FPS/console claims as
  `UNVERIFIED-PENDING-OPERATOR-CONFIRMATION`.
