# Engineer addendum — `game-dev-web` profile

When `profile-loader` reports the active profile as `game-dev-web`, these obligations are
added on top of `engineer.md`'s base contract. Adapted from `pair-programmer`'s
`engineer-game` addendum, narrowed to browser delivery (this harness has no console-cert,
netcode or live-ops capability and must not imply otherwise).

## 1. Read the gotcha pack first

Before composing any render or simulation code, read **`.claude/gotchas/web-engines.md`**
and treat it as a system-prompt addendum. Several entries there are marked **[observed]** —
they are failures this harness has actually shipped, not hypotheticals.

## 2. A green build is not evidence

`pnpm typecheck && pnpm lint && pnpm test && pnpm build` passing tells you the code is
well-formed. It tells you **nothing** about whether anything is on screen. Run
`20260726-213456-p1-render-foundation` passed all five and rendered a black screen.

Therefore, for any change touching rendering, lighting, camera or post-processing:

- **Never** state "renders correctly", "looks right", a frame-rate figure, or "console
  clean" as fact unless you hold capture evidence (see
  `.claude/rubrics/game-perf-budget.md` for what counts).
- If you cannot observe the running page, report those items verbatim as
  `UNVERIFIED-PENDING-OPERATOR-CONFIRMATION` and say plainly which claims are affected.
- Do **not** write a changelog in completed past tense about a visual outcome you have not
  seen. A judge is instructed to reject that.
- If you hold the N8 `mcp__claude-in-chrome__*` exception, gather the evidence rather than
  deferring. Absence of a browser is a reason to withhold a claim, never to assume one.

## 2b. Re-read every cited value from disk at write time

This applies to **any** agent writing a changelog, summary or release note for this profile, not
just the engineer — docs stages have now been rejected three times for the same defect
(runs `20260726-213456`, `20260727-081003`, `20260727-090143`).

The failure is not invention from nothing. It is **carrying numbers forward**: quoting a test count,
a colour value, a light intensity, an arithmetic result or a measurement from the *request prompt*,
from an *earlier draft*, or from *what the change was supposed to do* — rather than from the code as
it actually shipped. Plans change mid-run; a value that was true when the brief was written is
frequently false by the time the artifact is written.

So, before writing any specific value into an artifact:

- **If you have `Bash`** (e.g. `engineer`): re-derive from the repo. Test counts come from actually
  running the suite. Colour and material values come from the source file as committed. Arithmetic is
  recomputed from those re-read values. Never describe a change that is not in `git diff` / `git show`.
- **If you do NOT have `Bash`** (e.g. `docs-author`, whose allowlist is Read/Write/Edit/Glob/Grep):
  you cannot run the suite, produce a bundle size, or read git history — **do not pretend otherwise
  and do not estimate.** Cite figures from the project's persisted capture artifact,
  `docs/verification/phase-<n>-capture.md`, which exists precisely so these values have an on-disk
  source of truth. Source values you *can* read directly (colours, intensities, flags) may be read
  from the source file with `Read`/`Grep` and cited as such.
- **A number you cannot re-derive or read right now does not go in the artifact.** Write
  "unverified" instead. Fewer numbers, all true, beats a complete-looking set with invented entries.

This split matters: an earlier version of this rule told every author to "run the suite", which
`docs-author` is structurally incapable of doing. Demanding the impossible produces guessing, which
is exactly the defect the rule was written to prevent.

A judge is instructed to treat any mismatch between a cited value and the shipped code as an N4
false-verification claim and reject the stage. That is the correct outcome — a changelog whose
numbers are decorative is worse than one with fewer numbers.

## 3. Simulation state stays out of React

Entity state lives in the ECS or in refs — never in React state driven per frame. React
renders the shell (HUD, menus, map); it must not render the simulation. Assert this: a
render-count test on the HUD is cheap and catches the regression permanently.

## 4. Determinism

- Seed every RNG used by worldgen or simulation, with named sub-streams so adding a
  generator does not reshuffle existing content for a given seed.
- Fixed-timestep simulation with interpolated rendering, so feel is identical at 60 Hz and
  144 Hz. Assert this in a unit test across simulated frame rates.
- Never `Math.random()` inside a simulation tick.

## 5. Save-data atomicity

- Write via temp-key-then-swap; never overwrite a save in place.
- Every save carries a schema **version** field, with a migration path when it changes.
- A corrupt or unreadable save must surface a clear message and an export option — never a
  white screen or a silent reset.
- Round-trip and forced-migration tests are part of the change, not a follow-up.

## 6. Designer-tunable values are data, not code

Ship balance numbers — ship stats, module costs, mineral values, spawn tables, price
curves — in versioned `data/*.json` with a schema and a CI validator. Hardcoding them in
engine classes makes balancing a code change and blocks anyone who is not you from tuning.

## 7. Performance is a constraint, not a phase

- Pool anything spawned frequently; instance anything drawn more than a dozen times.
- Dispose geometries, materials and render targets explicitly — the GPU does not GC.
- Move heavy meshing/generation to a Web Worker with transferable buffers.
- Any perf-sensitive change requires a capture artifact per
  `.claude/rubrics/game-perf-budget.md`. A perf claim without one is an automatic reject.

## 8. Accessibility applies to the shell, and only partly to the canvas

WCAG governs the DOM layer (menus, settings, market screens): focus order, contrast,
keyboard reachability. It does not map cleanly onto a 3D canvas. For the canvas, deliver
the floor explicitly: remappable input, reduced-motion and reduced-shake options, subtitles
for voice and alerts, and signalling that never encodes meaning in hue alone. Do not report
a canvas game as WCAG-compliant on the strength of a DOM audit.

## 9. Stay inside the phase

Game plans are phased for a reason — the plan's later phases depend on earlier ones being
proven. Do not implement gameplay systems during a rendering phase, or asset-pipeline work
during a gameplay phase, however tempting the adjacency. If a phase boundary looks wrong,
say so and let the operator decide rather than quietly widening scope.
