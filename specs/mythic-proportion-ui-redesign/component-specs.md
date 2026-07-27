# mythic-proportion — Component Specs (Mycelial, Direction B)

Produced by `design-system-curator`. Covers the five existing shared components
under `web/src/components/ui/` (`Button`, `Input`, `Dialog`, `Tooltip`,
`Combobox`), against the Mycelial-revised token set in
`web/src/styles/tokens/{primitives,semantic,components,motion}.css`.

**Design dials**: DESIGN_VARIANCE=5, MOTION_INTENSITY=5, VISUAL_DENSITY=5 —
inherited unchanged from `specs/mythic-proportion-ui-redesign/aesthetic-directions.md`,
which itself explicitly defaulted all three (no `.fable/<run_id>/profile.json`
was resolvable there, and this task is likewise a standalone dispatch, not
inside an active run). Direction B expresses these mid-point dials
distinctively (moss accent, generous panel spacing, organic-but-restrained
motion) rather than via a numeric dial override; see that document for the
full framing. No divergence from the designer's stated values.

Every state matrix below follows the canonical 8-state discipline (default,
hover, focus, active, loading, empty, error, disabled). Where a state is
genuinely not applicable to a given component, that is stated explicitly with
reasoning — never silently skipped. Where a state's correct behavior could
not be determined with confidence from the existing code, it is flagged as an
**open question** per N4 rather than guessed.

Scope note: this document specifies intended states against the new token
contract. Wiring these into the components' own `.css`/`.tsx` files is Phase
3+ work (out of scope for this token-revision phase) — several states below
describe behavior the current markup does not yet implement (e.g. Button has
no `isLoading` prop today). Those are called out per-component.

---

## Button (`Button.tsx`, `button.css`)

**Props** (current): `variant?: "primary" | "secondary" | "ghost"` (default
`"primary"`), plus all native `ButtonHTMLAttributes`.

**Recommended additive prop for Phase 3** (not yet implemented — flagged, not
guessed into existence): `isLoading?: boolean`, to drive the Loading row
below. Today a consumer can only fake loading via `disabled` + external
spinner composition.

**Content slots**: `children` — required, any renderable node; convention in
this codebase is a short text label, optionally with a leading icon. No
enforced max length; long labels will wrap unless `white-space: nowrap` is
added by a consumer (not currently set).

| State | Spec |
|---|---|
| Default | `--button-bg`/`--button-fg` (primary), `--button-bg-secondary`/`--button-fg-secondary`/`--button-border-secondary` (secondary), transparent bg + `--button-fg-secondary` (ghost). Radius `--button-radius`, padding `--button-padding-y`/`-x` (now 8px/20px post-Mycelial space-4 change), font `--button-font-size` at weight 600. |
| Hover | `:not(:disabled):hover` swaps to `--button-bg-hover` (primary) / border to `--color-accent` (secondary) / bg to `--color-bg-elevated` (ghost) over `--duration-fast` `--ease-standard`. Unchanged behavior, now resolving through the moss accent. |
| Focus | `:focus-visible` inherits the global outline rule in `base.css` (`2px solid var(--color-accent)`, 2px offset) — not overridden per-component. No change needed; verified it still renders at ≥3:1 non-text contrast via the accent-vs-bg contrast test. |
| Active | `:active { transform: scale(0.98) }` over `--duration-instant`. Unchanged; a subtle press, not a bounce — consistent with Direction B's "restrained, not springy" motion stance even though this state isn't literally organic-eased (a press-scale is a distinct, universally-expected affordance separate from the organic/growth motion budget). |
| Loading | **Not yet implemented in code.** Intended spec: label replaced or accompanied by a spinner in `--button-loading-fg` / `--button-loading-fg-secondary` (matches that variant's own label color, so loading never reads as a color change); button remains focusable but should gain `aria-busy="true"` and typically `disabled` to prevent duplicate submits. Do NOT apply `.mp-breathing` here — that utility is reserved for genuinely long-running *background* states (see Disabled row), not an inline spinner, which should use a conventional continuous-rotation animation instead (not specified further here — rotation easing/duration is a Phase 3 decision, flagged as an **open question**, since Direction B's motion guidance doesn't cover spinner rotation explicitly). |
| Empty | **N/A** — `children` is required by the component's own type signature and every current call site passes a label; there is no meaningful zero-content variant to spec. |
| Error | **N/A, with a caveat.** The component exposes no `destructive`/error variant today (only `primary`/`secondary`/`ghost`). Errors in this app surface via Input/Dialog copy, not button color. If a destructive variant is added later, it should follow the existing variant pattern (`--button-bg` → `var(--color-danger)`, `--button-fg` → a contrast-checked neutral) rather than introducing a new token family. |
| Disabled | `:disabled { opacity: 0.5; cursor: not-allowed }` (unchanged). For the specific "Build Knowledge Graph" long-running case named in the aesthetic direction ("Growing the graph…"), apply `.mp-breathing` (motion.css) to the label/button for the slow single-loop breathing affordance — this is the ONE place Direction B authorizes a looping affordance, and only because it signals a genuinely long-running background job, not a static disabled state. Under `prefers-reduced-motion`, `.mp-breathing` falls back to a static `opacity: var(--breathe-min-opacity)` (0.6) rather than looping, per motion.css. Ordinary disabled buttons (not tied to a long-running job) must NOT get `.mp-breathing` — plain `:disabled` opacity is correct for those. |

**Accessibility notes**: native `<button>` — role is implicit, no `role`
attribute needed. Keyboard: Enter/Space activate (native). Focus ring
inherited from `base.css` global `:focus-visible`. `aria-busy` recommended
for the (not-yet-implemented) loading state above.

---

## Input (`Input.tsx`, `input.css`)

**Props** (current): all native `InputHTMLAttributes<HTMLInputElement>` — no
component-specific props; a thin forwardRef wrapper only.

**Content slots**: `value`/`placeholder` — plain text, no length constraint
enforced by the component (native `maxLength` attribute is available to
consumers via passthrough props). `placeholder` renders in
`--input-placeholder`.

| State | Spec |
|---|---|
| Default | `--input-bg` (bg-inset, now the tightened surface ramp), `--input-fg`, 1px `--input-border`, radius `--input-radius`, padding `--input-padding-y`/`-x`. |
| Hover | **Not implemented in current CSS** (no `:hover` rule exists on `.mp-input` today). New token `--input-border-hover` (`var(--color-border-strong)`) is added in `components.css` for Phase 3 to wire in as `.mp-input:hover:not(:disabled):not(:focus-visible) { border-color: var(--input-border-hover) }` — a subtle border-strengthen, no background change, consistent with the direction's restrained-hover language used elsewhere (dropzone hover: "a hairline moss-teal border fades in"). |
| Focus | `:focus-visible { border-color: var(--input-border-focus); outline: 2px solid var(--input-border-focus); outline-offset: 1px }` (unchanged, now resolving to the moss accent). |
| Active | **N/A, collapses into Focus.** Text inputs in this design system have no separate "pressed" visual distinct from the focused/editing state — the moment of typing IS the focused state. No separate token or rule is warranted. |
| Loading | **N/A for the primitive itself.** Plain `<Input>` has no built-in async operation (no debounced-search behavior is built into this component). Loading affordances belong to the *consuming composition* (e.g. a search field pairing `Input` with an external spinner icon) — not this primitive. If a future async-search wrapper is built around `Input`, it should use the new `--palette-loading-fg`-style pattern (a muted-text spinner), not invent a new color. |
| Empty | Empty value shows `placeholder` in `--input-placeholder` (`--color-text-secondary`) — unchanged, already contrast-audited via the body-text 4.5:1 pair. |
| Error | **Not implemented in current CSS.** New tokens `--input-border-error` (`var(--color-danger)`) and `--input-bg-error` (`var(--color-danger-wash)`, the warm low-alpha tint) are added in `components.css` for Phase 3: border switches to `--input-border-error`, background tints via `--input-bg-error` (a wash, not a hard fill, per Direction B's "error panel background tints warmly... as a wash, not a hard rule" language applied consistently to inline field errors too). Accompanying error text should sit in an adjacent `<span>`/`aria-describedby`'d element in `--color-danger`, not inside the input itself. |
| Disabled | `:disabled { opacity: 0.5; cursor: not-allowed }` (unchanged). No breathing/motion — disabled inputs are not long-running-job indicators, so the reserved breathing affordance does not apply here (this is the "never on static UI" boundary the direction is explicit about). |

**Accessibility notes**: native `<input>`, role implicit. Consumers are
responsible for pairing with a `<label>` (this component has no built-in
label slot) — **open question, flagged rather than assumed**: no current call
site was inspected as part of this token-only task to confirm labels are
consistently applied; recommend a follow-up accessibility pass on consuming
routes, not a design-system-curator action for this dispatch (N7 — that's
`designer`'s or `browser-validator`'s remit at the feature/flow level, not a
token/component-contract concern).

---

## Dialog (`Dialog.tsx`, `dialog.css` — thin wrapper over Radix `Dialog`)

**Props**: `DialogContent` takes `children`, `title` (required string),
`description?` (optional string), `className?`. `Dialog`/`DialogTrigger` are
re-exported Radix primitives directly (no local prop surface).

**Content slots**: `title` — required, single-line semantic heading (styled
`--font-size-lg`/weight 600); no enforced max length, but long titles will
wrap since no `white-space: nowrap` is set — acceptable given Direction B's
generous-text stance. `description` — optional single paragraph, styled in
`--color-text-secondary`/`--font-size-sm`; recommend consumers apply
`line-height: var(--line-height-relaxed)` (new primitive) here specifically,
since prose-breathing is exactly the case Direction B calls out. `children` —
arbitrary dialog body content (forms, lists, etc.), no slot-level constraint.

| State | Spec |
|---|---|
| Default | Overlay fades in (`mp-fade-in`, `--duration-fast`/`--ease-out`); content scales/translates in (`mp-scale-in`, `--duration-base`/`--ease-emphasized`) — unchanged animation curves. `--dialog-bg`/`-fg`/`-border`/`-shadow`/`-radius` all resolve through the revised semantic layer (tightened surface ramp, moss accent where used indirectly via focus rings on interior controls). |
| Hover | **N/A at the dialog-container level.** Hover applies to individual interactive elements *inside* the dialog (buttons, inputs, close control) — each specced under its own component above; the container itself has no hover-reactive treatment. |
| Focus | Radix manages focus-trap on open (focus moves to the first focusable element, typically the close button or first form field) and restores focus to the trigger on close — this is Radix's built-in behavior, unchanged by this token revision. Close-button/interior-control focus rings use the shared global `:focus-visible` rule. |
| Active | **N/A.** The dialog container is not itself a pressable/activatable element; "active" states belong to its interior controls. |
| Loading | **Not implemented in current CSS.** New token `--dialog-loading-fg` (`var(--color-text-secondary)`, deliberately neutral rather than accent-colored, so a loading spinner inside a dialog doesn't read as an actionable/accent element) is added for Phase 3 use in dialogs that load async content into their body (e.g. a confirmation dialog awaiting a status check). |
| Empty | Already supported structurally — `description` is optional in the current props; a dialog with only `title` + `children` and no description is a valid, already-working "empty description" state. No token change needed. |
| Error | **Not implemented in current CSS.** New tokens `--dialog-error-fg` (`var(--color-danger)`) and `--dialog-error-bg` (`var(--color-danger-wash)`) added for in-dialog validation/failure messaging (e.g. a form dialog's submit failure), following the same warm-wash-not-hard-fill treatment as Input's error state, for visual consistency across the two. |
| Disabled | **N/A for the dialog container itself** — dialogs don't have a "disabled" concept; individual interior controls (buttons, inputs) can be disabled and are specced under their own components. |

**Accessibility notes**: Radix `Dialog` provides the ARIA dialog role, labeling
(via `Title`/`Description`), focus trap, and Escape-to-close — all
unchanged by this revision. `RadixDialog.Overlay` and `.Content` retain their
existing animation-on-mount behavior; no new a11y concern introduced by the
token changes (color/spacing/radius only).

---

## Tooltip (`Tooltip.tsx`, `tooltip.css` — thin wrapper over Radix `Tooltip`)

**Props**: `content: ReactNode` (required), `children: ReactNode` (required —
the trigger element, wrapped via Radix `asChild`). `delayDuration` is
hardcoded to `300` in the component (not exposed as a prop).

**Content slots**: `content` — short, ideally single-line text or a small
inline node; no enforced max length, but tooltip content is not designed for
paragraphs (padding is `--space-1`/`--space-2`, deliberately tight — this is
one of the few places Direction B's "generous spacing" doesn't apply, since a
tooltip is a transient micro-affordance, not a reading surface).

| State | Spec |
|---|---|
| Default | Closed — renders nothing (Radix unmounts content when not open). |
| Hover | Hovering the trigger (after `delayDuration: 300`) opens the tooltip: `mp-fade-in` over `--duration-fast`/`--ease-out`, styled via `--tooltip-bg`/`-fg`/`-radius`/`-shadow` (now the tightened surface ramp for `-bg`). |
| Focus | Keyboard-focusing the trigger also opens the tooltip (Radix's built-in a11y behavior — tooltips must be keyboard-discoverable, not hover-only) — same visual treatment as Hover. Not a separately styled state; documented here to confirm it's covered, not skipped. |
| Active | **N/A.** The tooltip itself is not a clickable/pressable element; it has no press-state distinct from its open/closed state, which is already covered by Hover/Focus above. |
| Loading | **N/A.** Tooltip content is static/synchronous at render time in every current call site; there is no async-content variant to spec. |
| Empty | **N/A.** `content` is a required prop; there is no supported zero-content variant. (If a consumer passes an empty string, Radix will still mount an empty bubble — not guarded against today; flagged as a minor **open question** for Phase 3, not fixed here since it's a markup-guard change, not a token concern.) |
| Error | **N/A.** Tooltips carry no error semantics in this design system; error messaging belongs to Input/Dialog. |
| Disabled | **Open question, flagged rather than guessed.** Radix's `Tooltip.Trigger` with `asChild` wrapping a native `disabled` button is a known cross-browser footgun: disabled elements don't reliably fire the pointer/focus events Radix listens for, so a tooltip meant to explain *why* a control is disabled may simply never open. Confidence is genuinely low on whether any current call site relies on this pattern (not audited as part of this token-only task) or on what the intended behavior should be (show explanation vs. suppress entirely). Recommend a follow-up pass — by `designer` (if it's a flow-level UX decision) or `engineer` (if it's implementation-only, e.g. wrapping the disabled button in a focusable/hoverable non-disabled span) — before Phase 3 touches this component. |

**Accessibility notes**: Radix supplies the tooltip ARIA wiring
(`aria-describedby` linking trigger to content) and the hover+focus dual
trigger described above. No change from this token revision beyond color/
radius/shadow resolving through the new semantic layer.

---

## Combobox (`Combobox.tsx`, `combobox.css` — thin wrapper over `cmdk`)

**Props/sub-components**: `Combobox` (root), `ComboboxInput`, `ComboboxList`,
`ComboboxEmpty`, `ComboboxGroup`, `ComboboxItem`, `ComboboxSeparator` — all
direct re-exports of `cmdk`'s `Command.*` primitives; no local prop surface
beyond `cmdk`'s own (`value`/`onValueChange`, `disabled` per-item, etc.).

**Content slots**: `ComboboxInput` — free-text query, no length constraint.
`ComboboxItem` children — short label text, ideally single line (list rows
have fixed vertical rhythm via `--space-2`/`-3` padding). `ComboboxGroup`
`heading` — short uppercase label (styled `text-transform: uppercase`,
`letter-spacing: 0.04em`) — should stay short (a handful of words) since it's
rendered without wrapping guards.

| State | Spec |
|---|---|
| Default | Closed-list-not-rendered or list-with-items-visible — `--palette-bg`/`-fg`/`-border`/`-radius`/`-shadow`, now the tightened surface ramp for `-bg`. |
| Hover | `cmdk` sets `data-selected="true"` on the currently *highlighted* item whether highlighted by mouse hover or keyboard arrow-navigation — the two are not visually distinguished in this component (both render via `--palette-item-bg-active`/`-fg-active`). This is `cmdk`'s own default behavior, not something this token revision changes; documented here so Hover isn't mistaken for an unspecced state. |
| Focus | `[cmdk-input]:focus { outline: none }` in current `combobox.css` — **a real WCAG 2.4.7 (focus-visible) gap**: the input's native focus ring is explicitly suppressed and nothing replaces it. This is a pre-existing issue, not introduced by this token revision, but it should be fixed before/alongside any Mycelial visual polish lands on this component. New token `--palette-input-focus-ring` (`var(--color-accent)`) is added in `components.css` as the settled value for that fix (e.g. a focus-visible box-shadow ring on the `[cmdk-root]` container, since the input itself has no border to color) — not applied in `combobox.css` in this phase, since that file edit is out of scope here. |
| Active | Selected/highlighted item — `--palette-item-bg-active`/`-fg-active` (now moss accent bg + on-accent text). Same token names as before, new color resolution. |
| Loading | **Not implemented — `cmdk` has no built-in async/loading UI.** New token `--palette-loading-fg` (aliases `--palette-item-fg-muted`) is added for a consumer-implemented "Searching…" row (rendered as a plain list item, not a special component) when combobox is wired to async/debounced filtering (e.g. a future vault-wide fuzzy search backed by the API rather than in-memory `cmdk` filtering). |
| Empty | `[cmdk-empty]` already styled (`--palette-item-fg-muted`, centered, `--font-size-sm`) — unchanged, this is `cmdk`'s built-in no-results state. |
| Error | **N/A today, open question for the async case.** With `cmdk`'s current in-memory filtering there is no error condition to represent. If/when async filtering (see Loading row) is added, an error row would need its own token (likely `--color-danger` text in a plain list-item row, mirroring the Loading row's pattern) — not specified further here since the async-search feature itself doesn't exist yet; speculative token invention for a feature not yet designed would violate N4. |
| Disabled | `[cmdk-item][data-disabled="true"] { opacity: 0.4; cursor: not-allowed }` (unchanged) — distinct opacity value from the shared `--opacity-disabled`-style pattern used elsewhere (0.4 here vs. 0.5 on Button/Input); this is a pre-existing inconsistency, not introduced by this revision, flagged for a possible future consolidation but not changed here since it's outside this dispatch's stated scope (token/state revision, not a cross-component consistency audit). |

**Accessibility notes**: `cmdk` provides ARIA combobox/listbox semantics and
arrow-key/Enter navigation internally. The focus-visible gap on
`[cmdk-input]` (Focus row above) is the one concrete a11y issue surfaced by
this review; everything else is `cmdk`'s existing, unchanged behavior.

---

## Component-preview artifact description

No live Storybook/preview source files were written in this task (not
requested by the dispatch, and the guardrail against overclaiming a rendered
artifact applies) — this section is a structured *description* of what such
a preview should show, for whoever builds it in Phase 3+.

**Layout**: one preview panel per component (Button, Input, Dialog, Tooltip,
Combobox), each rendered twice side-by-side — once under `[data-theme="dark"]`,
once under `[data-theme="light"]` — so the moss-accent/tightened-surface
remap is checkable in both themes at a glance.

**Per-component prop/state matrix panel**:
- **Button**: a 3×4 grid — rows = variant (`primary`/`secondary`/`ghost`),
  columns = state (default, hover [`:hover` pseudo-class forced via a
  `.force-hover` test class], focus [`.force-focus-visible`], disabled).
  Loading is shown as a mocked row once Phase 3 implements `isLoading` (not
  renderable today — the preview should show a placeholder note "not yet
  implemented" rather than fabricate the row).
- **Input**: a single column — default, hover, focus, error, disabled — each
  a labeled input with representative placeholder text ("Search your vault…").
- **Dialog**: one open instance per theme showing title + description +
  a form-like body, to visually confirm the tightened `--dialog-bg` surface
  step against `--dialog-overlay-bg`.
- **Tooltip**: a row of trigger buttons, each with its tooltip pinned open
  (via Radix's `open` controlled prop) so all can be screenshotted
  simultaneously rather than requiring live hover.
- **Combobox**: one instance with a populated list (showing the
  `data-selected` active-item treatment), one instance with `[cmdk-empty]`
  showing (no matches), one instance with a `data-disabled="true"` item
  visible in the list.

**Annotations expected in the real preview**: each panel should surface the
resolved computed value of its component's key tokens (e.g. Button's
`--button-bg`, Input's `--input-border-error`) as an on-page caption, so a
reviewer can confirm token resolution without opening devtools — this is a
convention already implied by the "structured markdown description of what a
live component-preview would show" contract, not a new requirement invented
here.
