# Rubric: WCAG 2.2 AA accessibility stability

Applies to: UX/design artifacts from `designer.md` and `design-system-curator.md` (§4.4). Skipped (not applicable) for non-UI profiles per `profile-loader.md`'s output.

## Checks

1. All 8 canonical interaction states are addressed (default/hover/focus/active/loading/empty/error/disabled) — not just the happy-path default state.
2. Focus order and keyboard-operability are stated explicitly for any new interactive component.
3. Color is never the sole means of conveying information/state (contrast + a non-color signal both present).
4. Content/microcopy avoids ableist or exclusionary phrasing; error messages are actionable, not just "something went wrong."
5. Any DESIGN_VARIANCE/MOTION_INTENSITY dial set above a low value is checked against `prefers-reduced-motion` handling.

## Verdict mapping

- `pass`: all 5 checks satisfied.
- `pass-with-notes`: checks 1-3 satisfied, 4-5 have minor gaps.
- `reject`: missing coverage of the 8 interaction states, or color-only state signaling with no alternative.
