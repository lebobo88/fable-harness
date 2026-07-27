# Rubric — game performance budget (browser tiers)

**Applies to:** any perf-tagged stage under the `game-dev-web` profile (taxonomy §4.8, §4.10).
**Adapted from** `pair-programmer`'s console-oriented `game-perf-budget@1`, re-derived for
browser delivery — there is no PS5 tier here, and no Unreal Insights capture either.

## The rule that matters most

> **A performance claim without capture evidence is an automatic `reject`.**

Not `pass-with-notes`. Not "plausible". A stated frame rate, a "smooth at 60fps", a
"no regression" — each requires an artifact showing a measurement that actually happened.
This rule exists because run `20260726-213456-p1-render-foundation` checked off
"60fps @ 1080p verified by perf probe" having measured nothing at all, on a build that
rendered a black screen.

## Target tiers

Browser games do not have fixed hardware. Tiers are defined by the app's own quality
setting plus a representative GPU class, and **a claim must name which tier it was
measured on**.

| Tier | Representative GPU | Frame budget | Draw calls | JS heap growth | Bundle (gzip JS) |
|---|---|---|---|---|---|
| ultra | discrete high-end (RTX 3080+) | 16.67 ms | < 1500 | flat over 30 min | — |
| high | discrete mid-range (RTX 3060 / RX 6600) | 16.67 ms | < 1000 | flat over 30 min | < 2 MB |
| medium | entry discrete / high-end integrated | 20 ms | < 700 | flat over 30 min | < 2 MB |
| low | integrated (Iris Xe, Vega 8) | 33.3 ms | < 400 | flat over 30 min | < 2 MB |

**Measuring on a GPU above the claimed tier does not satisfy that tier.** A 60fps result
on an RTX 3080 Ti is evidence about the ultra tier and says nothing about whether an
Iris Xe holds 30fps. Report it as the data point it is.

**Vsync caps measurement.** A locked 60.0 fps with p99 ≈ 16.7 ms proves the budget is met
but reveals nothing about headroom. State this whenever it applies rather than implying
the result is a ceiling.

## Accepted capture evidence

At least one of, referenced by path in the artifact:

- A `requestAnimationFrame` frame-time sample (≥ 180 frames, warm-up discarded) reporting
  avg / p50 / p95 / p99 / max, plus backbuffer resolution and `devicePixelRatio`.
- Chrome DevTools Performance trace (`.json`) or a GPU frame capture.
- `r3f-perf` / engine-native counters captured on a **fixed, deterministic camera path** —
  a hand-flown route is not reproducible and is not evidence.
- A console-message census: total count, error count, warning count, over a stated idle
  duration. ("No errors" is a measurement, not an assumption.)
- Bundle-size output from the build plus the budget assertion result.

## Scored clusters (0..1 each)

- **frame_time** — avg and p99 within the claimed tier's budget on a deterministic path.
- **frame_stability** — p99 within ~1.5× p50; no single frame above 2× budget. A 60fps
  average hiding 100 ms hitches is a fail, not a pass.
- **memory** — JS heap and GPU texture memory flat across a sustained session; no leaked
  WebGL resources; pooling in place for anything spawned per-frame.
- **draw_calls** — within tier ceiling on the heaviest representative scene; instancing
  used for anything appearing more than a dozen times.
- **console_cleanliness** — zero errors, zero warnings, sustained (not just at boot). A
  warning firing thousands of times while idle is a defect, not noise.
- **load_time** — cold load to interactive within the project's stated target.
- **capture_evidence** — every metric above is backed by a referenced artifact.

## Outcome

- **pass** — every cluster ≥ 0.7 AND `capture_evidence` present for each claimed metric.
- **pass-with-notes** — every cluster ≥ 0.7, evidence present, minor tuning items noted.
- **reject** — any cluster < 0.5, OR any perf claim asserted without capture evidence,
  OR a measurement cited from a hardware tier other than the one being claimed without
  that discrepancy being stated plainly.

## Interaction with N8 and N4

Agents holding the `mcp__claude-in-chrome__*` exception may gather this evidence
themselves. Agents without it **must not** infer it: per N4 a validator that cannot
validate returns `reject`, and per the `game-dev-web` profile the honest report is
`UNVERIFIED-PENDING-OPERATOR-CONFIRMATION`. Absence of a browser is a reason to withhold
a verdict, never a reason to grant one.
