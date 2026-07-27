# mythic-proportion — Motion Consolidation & Verification Spec (Mycelial, Direction B)

Produced by `design-system-curator`. This is a **consolidation + verification** pass over motion
already implemented across five independent engineering dispatches (ingest, shell/nav +
command-palette, wiki + search + ask, lint + settings, graph) — not new motion design. Per the
dispatch's own framing, trivial token-name/value corrections are made directly; anything that
would require a real design judgment call is flagged as an open question instead.

**Design dials**: DESIGN_VARIANCE=5, MOTION_INTENSITY=5, VISUAL_DENSITY=5 — inherited unchanged
from `aesthetic-directions.md` / `component-specs.md` (both explicitly defaulted all three; no
`.fable/<run_id>/profile.json` was resolvable for this standalone task either). No divergence
from the previously-stated values.

**Sources of truth consulted**: `web/src/styles/tokens/motion.css` (the single token file), every
route/component `.css` file under `web/src` (23 files), `specs/mythic-proportion-ui-redesign/aesthetic-directions.md`
(Direction B's motion paragraph — the actual authoritative bounds), `component-specs.md` (Button's
disabled/breathing row), and `specs/mythic-proportion-ui-redesign.html` (Phase 2 outcome notes,
confirming `--duration-growth: 280ms` / `--duration-breathe: 2400ms` as the settled values).

---

## 1. Token inventory (`motion.css`)

| Token | Value | Reduced-motion value |
|---|---|---|
| `--duration-instant` | 100ms | 0ms |
| `--duration-fast` | 150ms | 0ms |
| `--duration-base` | 225ms | 0ms |
| `--duration-slow` | 350ms | 0ms (**unused** — see §5) |
| `--duration-growth` | 280ms | 0ms |
| `--duration-breathe` | 2400ms | 0ms (`.mp-breathing` has its own static-opacity fallback instead, see §3) |
| `--ease-standard` | `cubic-bezier(0.2, 0, 0, 1)` | n/a |
| `--ease-out` | `cubic-bezier(0, 0, 0.2, 1)` | n/a |
| `--ease-emphasized` | `cubic-bezier(0.05, 0.7, 0.1, 1)` | n/a |
| `--ease-organic` | `cubic-bezier(0.22, 1, 0.36, 1)` | n/a |

`--duration-instant/-fast/-base/-slow` + `--ease-standard/-out/-emphasized` are the pre-Mycelial
generic set (unchanged by this redesign). `--ease-organic`, `--duration-growth`, `--duration-breathe`
are the Mycelial additions.

---

## 2. Interaction-category → token/route consolidation table

| Category | Token(s) | Routes/components using it | Reduced-motion fallback |
|---|---|---|---|
| **Organic background-color settle** (panel/row background shifts on hover or theme-adjacent state) | `--duration-base` (225ms) + `--ease-organic` | `.mp-ingest-dropzone`, `.mp-graph-filter`, `.mp-graph-hint`'s sibling pattern (see note), `.mp-wiki-page-item`, `.mp-search-result-card`, `.mp-settings-panel`, `.mp-lint-panel`, `.mp-app-shell` / `.mp-app-shell-subheader`, `.mp-header` | Global kill-switch (zeroes `--duration-base`, forces `transition-duration: 0.01ms`) |
| **Hairline border-color fade** (standard, non-organic — deliberately a plain color snap-fade, per Direction B's own "hairline border fades in (150ms)" language) | `--duration-fast` (150ms) + `--ease-standard` | `.mp-ingest-dropzone`, `.mp-graph-filter`, `.mp-graph-hint`, `.mp-wiki-page-item`, `.mp-search-result-card`, `.mp-input`, `.mp-button`, `.mp-settings-select`, `.mp-header-shortcut` | Global kill-switch |
| **Restrained lift on hover** (1-2px `translateY`, "restrained, not springy") | `--duration-fast` (150ms) + `--ease-organic` | `.mp-ingest-dropzone`, `.mp-graph-filter`, `.mp-wiki-page-item` (uses `translateX(1px)`), `.mp-search-result-card` | Global kill-switch |
| **Underline/fill growth** (progress bar width, active-tab underline `scaleX`) | `--duration-base` (225ms) + `--ease-organic` | `.mp-ingest-progress-fill`, `.mp-tab::after` (+ `.mp-tab` color/background) | Global kill-switch |
| **One-shot grow-into-place on mount** (list/card/pane entry — opacity 0→1 + `translateY(-4px→0)`) | `--duration-growth` (280ms) + `--ease-organic` | `.mp-ingest-file` (`mp-ingest-row-grow`), `.mp-graph-reading-pane` (`mp-graph-pane-grow`), `.mp-ask-box` (`mp-ask-box-grow`), `.mp-lint-section` (`mp-lint-section-grow`), `.mp-search-result-card` (`mp-search-row-grow`) | Global kill-switch (`animation-duration: 0.01ms`, `animation-iteration-count: 1`) |
| **One-shot root-tendril line-draw** (SVG `stroke-dashoffset`, drag-over only) | `--duration-growth` (280ms) + `--ease-organic` | `.mp-ingest-tendril path` (`mp-ingest-tendril-trace`) — the single deliberate "living graph" motion moment named in Direction B | Global kill-switch |
| **Breathing / long-running-only loop** | `--duration-breathe` (2400ms) + `--ease-organic`, `infinite` | `.mp-breathing` utility, applied exactly once: `IngestView.tsx`'s "Build Knowledge Graph" button while `graphBuilding` is true | Own scoped fallback: `animation: none !important; opacity: var(--breathe-min-opacity) !important` (static reduced-opacity, not a frozen mid-loop frame) |
| **Overlay/tooltip fade-in** | `--duration-fast` (150ms) + `--ease-out` | `.mp-dialog-overlay` (`mp-fade-in`), `.mp-tooltip-content` (`mp-fade-in`) | Global kill-switch |
| **Modal content scale/pop-in** | `--duration-base` (225ms) + `--ease-emphasized` | `.mp-dialog-content` (`mp-scale-in`) — single instance, pre-existing generic curve, not part of the organic vocabulary | Global kill-switch |
| **Listbox/menu item highlight — shared `cmdk` default** | `--duration-instant` (100ms) + `--ease-standard` | `[cmdk-item]` in `combobox.css` (shared infrastructure; deliberately out of scope for the Mycelial pass per that file's own header comment) | Global kill-switch |
| **Listbox/menu item highlight — Command Palette override** | `--duration-fast` (150ms) + `--ease-organic` | `.mp-command-palette-content [cmdk-item]` — explicitly documented in `command-palette.css` as an intentional, scoped override of the shared combobox default | Global kill-switch |
| **Press-scale utility** (`:active { transform: scale(...) }`) | `--duration-instant` (100ms) + `--ease-standard` | `.mp-button:active` (`scale(0.98)`) | Global kill-switch |
| **Checked-state scale affordance** | `--duration-fast` (150ms) + `--ease-standard` | `.mp-settings-checkbox input[type="checkbox"]:checked` (`scale(1.05)`) | Own explicit local override (`transition: none; transform: none`) **and** covered by the global kill-switch — intentionally redundant, documented in `settings.css` for reviewer legibility |

---

## 3. Consistency verification — no drift found requiring correction

Every "equivalent interaction, different route" pair was checked token-by-token:

- **Background-color settle on hover/mount** (ingest dropzone, graph filter, wiki page item,
  search result card, settings panel, lint panel, app shell, header) — **all** use
  `var(--duration-base) var(--ease-organic)`, byte-identical. No drift.
- **Grow-into-place keyframes** (ingest file row, graph reading pane, ask answer box, lint
  section, search result card) — **all five** keyframe blocks are byte-identical
  (`opacity: 0 → 1`, `transform: translateY(-4px) → translateY(0)`), and all five animations use
  `var(--duration-growth) var(--ease-organic)`. No drift.
- **Hairline border fade** (dropzone, graph filter, wiki item, search card, input, button,
  settings select, header shortcut) — all use `var(--duration-fast) var(--ease-standard)`. No drift.
- **Restrained hover lift** — all use `var(--duration-fast) var(--ease-organic)`. No drift.

**One genuine divergence found, judged intentional (not fixed)**: the Command Palette's
`[cmdk-item]` highlight uses `--duration-fast`/`--ease-organic` (150ms, organic) while the shared
`combobox.css` default for the same underlying `cmdk` primitive uses `--duration-instant`/
`--ease-standard` (100ms, linear-ish standard curve). `command-palette.css` documents this
explicitly as a deliberate, narrowly-scoped override (palette-only selector specificity beats the
shared rule) rather than an accidental drift — the rationale given is that the palette wants the
same "organic-eased" language as the rest of Direction B's list rows, while `combobox.css` itself
was called out-of-scope for this redesign (shared infrastructure, other non-palette consumers of
`Combobox` still get the plain default). **Flagged as an open question below (§6)** rather than
silently reconciled, since collapsing it to one shared value either way is a real design choice
(does every `cmdk` consumer deserve the organic highlight, or is instant-highlight correct for
faster keyboard-driven contexts generally?) — not a token-name typo.

No other duration/easing pairing was found to differ between routes for what is otherwise the same
interaction. **No trivial token-name corrections were needed anywhere** — the five engineering
dispatches converged on a consistent vocabulary already.

---

## 4. `prefers-reduced-motion` coverage verification

- The global kill-switch in `motion.css` (`@media (prefers-reduced-motion: reduce)`) zeroes every
  `--duration-*` custom property to `0ms` **and** forces `animation-duration: 0.01ms !important`,
  `animation-iteration-count: 1 !important`, `transition-duration: 0.01ms !important`,
  `scroll-behavior: auto !important` on `*, *::before, *::after`. Because every transition/animation
  in the app is authored as `<property> var(--duration-*) var(--ease-*)` (verified by grep across
  all 23 touched CSS files — see §5), none can bypass this: there is no hardcoded millisecond value
  anywhere in a `transition`/`animation` declaration.
- **`.mp-breathing`** is the one case that needs — and has — its own scoped override: without it,
  the generic kill-switch would merely freeze the loop at whatever the forced 1-iteration/0.01ms
  run happens to land on (typically full opacity), silently defeating the "reduced" signal. Its
  local rule (`animation: none !important; opacity: var(--breathe-min-opacity) !important`)
  correctly replaces the loop with the static 0.6-opacity fallback.
- **`.mp-settings-checkbox input[type="checkbox"]:checked`**'s local `prefers-reduced-motion`
  block is redundant with the global kill-switch (both zero the transition/transform), but
  intentionally so per its own code comment — documenting the reduced-motion intent next to the
  component it applies to. Redundant-but-correct, not a bug.
- **The ingest root-tendril trace** (`mp-ingest-tendril-trace`) relies entirely on the global
  kill-switch (per its own code comment) rather than a local override — verified correct, since a
  one-shot `forwards`-filled animation reduces cleanly to its end frame under
  `animation-iteration-count: 1` + near-zero duration (the SVG path simply appears fully drawn
  instantly, which is the same "no motion" outcome the direction wants).
- No animation/transition was found in any file that is (a) missing a token reference (hardcoded
  `ms`/`s` value), (b) a `@keyframes` block invoked outside the global `animation-duration`
  override's `*` selector reach, or (c) a JS-driven imperative animation outside CSS (the R3F
  camera-ease code in `src/lib/motion.ts`, referenced by `motion.css`'s own header comment, was out
  of scope for this CSS-file grep pass — flagged in §6 as a follow-up check, not verified here).

**Conclusion: full coverage confirmed for every CSS-authored animation/transition in `web/src`.**

---

## 5. Bounds verification against Direction B's stated motion vocabulary

Per `aesthetic-directions.md` (Direction B): *"Motion: organic easing (custom cubic-bezier
resembling a settling/branching motion, ~200-280ms) — things 'grow into place' rather than snap; a
subtle looping 'breathing' affordance only on genuinely long-running states... never on static
UI."* The ingest-page paragraph additionally specifies the hover border fade at **150ms** and the
root-tendril trace at **~300ms** (settled at 280ms, reusing `--duration-growth` rather than
inventing a near-duplicate token — within the stated "~200-280ms" range, and the plan's own Phase 2
outcome note confirms 280ms as the settled value, not 300ms).

| Bound | Stated range | Actual token(s) | In bounds? |
|---|---|---|---|
| Organic settling / grow-into-place | ~200-280ms | `--duration-growth` = 280ms (one-shot mount/trace animations); `--duration-base` = 225ms (organic background/underline transitions) | Yes |
| Hover border hairline fade (explicitly named at 150ms in the source doc) | 150ms | `--duration-fast` = 150ms | Yes — matches exactly |
| Breathing / long-running loop | ~2-3s | `--duration-breathe` = 2400ms | Yes |
| Standard (non-organic) micro-transitions — border-color snaps, press-scale, instant listbox highlight | Not explicitly bounded by Direction B (pre-existing generic tokens, called out in `motion.css`'s own header comment as "kept... UNCHANGED — still the right choice for ordinary hover/focus/press transitions, not every transition needs to feel organic") | `--duration-instant` = 100ms, `--duration-fast` = 150ms | See note below |

**Note on `--duration-instant`/`--duration-fast` vs. a generic "0.2-0.3s standard interaction"
expectation**: a plausible reading of "standard interactions should be 0.2-0.3s" would put 100ms and
150ms out of bounds. However, tracing this to the actual authoritative source
(`aesthetic-directions.md`) shows Direction B **explicitly specifies 150ms** for the hover
border-fade case, and `motion.css`'s own header comment explicitly designates the pre-existing
100/150/225/350ms set as intentionally **not** part of the organic-motion budget — they're generic
UI micro-feedback (press-scale, instant listbox highlight, hairline border snaps) that predate this
redesign and were deliberately kept unchanged. Judged **in bounds** against the actual design intent
as documented, not against a generic "0.2-0.3s for everything" reading. Flagged as a confirmation,
not a violation — see §6 if a stricter global floor of 200ms for all transitions is actually
intended, which would require revisiting `--duration-instant`/`--duration-fast` themselves (a real
token-value change, out of scope for a trivial fix, and would need the N9 preserved-invariants
treatment since `--duration-instant`/`--duration-fast` are consumed by many pre-existing components
outside this redesign's scope).

`--duration-slow` (350ms) is defined in `motion.css` but **not referenced anywhere** in the current
`web/src` CSS — a dead/reserved token, not a bound violation (nothing uses it, so nothing can be out
of bounds). Left as-is; not a defect, just noted for completeness.

---

## 6. Open questions (flagged, not guessed — per N4)

1. **Command Palette's organic item-highlight override vs. shared Combobox's instant default**
   (§3): should every `cmdk`-based listbox consumer in the app eventually converge on one shared
   highlight token (and if so, which — the palette's 150ms/organic, or the shared 100ms/standard?),
   or is the current split intentional and permanent (rapid keyboard-driven palette navigation
   wanting a slightly more "alive" feel than a plain data list)? This is a real design judgment call,
   not a naming typo — left unresolved.
2. **`--duration-instant`/`--duration-fast` vs. a stricter "0.2-0.3s floor for all standard
   interactions" reading** (§5): if the intended global rule really is "no standard-interaction
   transition may run under 200ms," that would require raising `--duration-instant` (100ms) and
   `--duration-fast` (150ms) themselves — a breaking token-value change touching every consumer
   listed in §2's border-fade/press-scale/instant-highlight rows across the whole app, not just the
   Mycelial-touched files. Per N9, this needs an explicit Preserved-Invariants-vs-Changed-Behaviors
   review (and likely a `security-reviewer`/`verifier` pass on visual regression) before being
   attempted — not undertaken here, since this dispatch is verification/consolidation-only and no
   evidence was found that 100ms/150ms usage is a *mistake* rather than a deliberate, source-doc-
   confirmed choice.
3. **JS-driven imperative motion** (R3F camera eases in `src/lib/motion.ts`, referenced by
   `motion.css`'s own header comment as "the matching JS-side helpers used by imperative code") was
   not audited in this pass — this dispatch's grep coverage was CSS-file-scoped only. Recommend a
   follow-up pass specifically confirming the graph camera-rig eases also respect
   `prefers-reduced-motion` (likely via a JS-side media-query check mirroring the CSS kill-switch,
   since CSS custom properties aren't directly readable by Three.js/R3F imperative code without an
   explicit JS bridge). Not fixed here — outside this task's CSS-file scope and a genuine
   implementation question, not a trivial correction.
4. Button's spinner-rotation easing/duration (already flagged as open in `component-specs.md`,
   carried forward unchanged here) remains unresolved — no rotation animation exists in code yet to
   verify against.

---

## 7. Trivial fixes applied

**None.** Every equivalent-interaction category was already using a consistent token pair across
all five independent dispatches; no hardcoded-duration bypass of the `prefers-reduced-motion`
kill-switch was found; no animation fell outside Direction B's actual stated bounds once traced to
the authoritative source document. This pass is therefore a clean bill of health with one
documented-but-flagged design-judgment divergence (§6.1) and one scope-bounded follow-up
recommendation (§6.3) — no CSS files were edited.

---

## 8. Test verification

`cd web && npx vitest run` — **106/106 tests passed, 17/17 test files passed** (no source changes
were made, so this run is a confirmation of pre-existing green state, not a regression check
against a fix).
