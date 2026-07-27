# Gotcha pack — web game engines (three.js / React Three Fiber, Babylon.js, PlayCanvas, Phaser)

Read this **before writing render or simulation code** under the `game-dev-web` profile.
Treat it as a system-prompt addendum, not background reading.

Adapted from `pair-programmer`'s `web-engines` pack, extended with failures this harness
has actually produced (marked **[observed]** — those are not theoretical).

**Editing convention — corrections REPLACE, they never accumulate.** If an entry here is wrong or
imprecise, rewrite that entry in place so the pack carries exactly one statement per trap. Do NOT
append a second entry that contradicts or refines an existing one, and do not leave a "corrected by
X on DATE" note inside the prose — this is a fast-read system-prompt addendum, not an append-only
ledger, and a reader who hits two overlapping entries has to adjudicate between them at exactly the
moment they needed a straight answer. (The append-only discipline that governs
`memory/invariants.md` and plan Amendments deliberately does **not** apply to this file.) If a
correction is itself significant enough to record as history, put that in `memory/invariants.md`
and keep the entry here clean.

## Universal

- **`requestAnimationFrame` is the only correct render loop.** `setInterval` / `setTimeout`
  are wrong: they drift, they don't pause on hidden tabs, and they decouple from vsync.
- **No allocations in the render loop.** No `new`, no object/array spread, no `.map()` /
  `.filter()`, no closure creation per frame. Reuse pre-allocated vectors and matrices;
  pool anything spawned repeatedly (projectiles, particles, debris). GC pauses read as
  stutter and will not show up in an average frame-time figure.
- **Fixed-timestep simulation, interpolated render.** Otherwise game feel changes between
  a 60 Hz and a 144 Hz display, and physics becomes frame-rate dependent.
- **Seed your RNG.** `Math.random()` inside worldgen or simulation makes bugs
  irreproducible and save files meaningless.
- **Assume the GPU can be lost.** Handle `webglcontextlost` / `webglcontextrestored`;
  a laptop waking from sleep should not white-screen the game.
- **Measure, never estimate.** See `.claude/rubrics/game-perf-budget.md`.

## three.js / React Three Fiber

- **Simulation state must live outside React.** Put entity state in an ECS (miniplex or
  similar) or in refs. A `setState` per frame re-renders the tree 60 times a second and is
  the single most common R3F performance disaster. React renders the *shell* (HUD, menus);
  it must not render the *simulation*.
- **[observed] Effect wrappers can reconstruct every render.** `@react-three/postprocessing`
  v3.0.4's `SelectiveBloom` and `GodRays` include a freshly-created rest-spread props object
  in their internal `useMemo` dependency array, so the underlying `postprocessing`
  `Effect`/`Selection` is rebuilt on *every* render. Each rebuild allocates another render-
  layer ID from a module-level counter with **30 slots (2..31)**; once exhausted it emits
  `Layer out of range, resetting to 2` and can drive an infinite React update loop
  (`Maximum update depth exceeded`). Wrapping the component in `React.memo` was tried and
  was **not** sufficient. If you hit this, stabilise every prop identity including ref
  arrays, construct the effects imperatively and mount via `<primitive>`, or use plain
  `Bloom` instead of `SelectiveBloom`.
- **[observed] `GodRays` blacks the entire frame when its sun source is off-screen.** It
  raymarches from the light's projected screen position; off-frustum, the composite output
  is pure black — with no error, no warning, and a completely green build. If the screen is
  black, bisect the post stack one effect at a time before suspecting anything else.
- **[observed] Reconcile camera, key light and hero-object placement as ONE decision.**
  Deriving a planet's position from `sunDirection.negate()` guarantees it sits diametrically
  opposite the sun and therefore outside any frustum containing the sun. Compute the actual
  off-axis angle against the camera's forward vector and check it against the fov before
  assuming something is in shot.
- **Backlight is cinematic; silhouette is a bug.** Putting the key light near the camera
  axis (required for lens flare and god rays) necessarily backlights every subject. Add fill
  — ambient, a hemisphere light keyed to the sky palette, or a dim cool kicker opposite the
  key — or subjects render as flat black cutouts.
- **`depthTest: false` + `renderOrder`** is how you fake a far layer without a second camera.
  Order matters: a later `renderOrder` with depth disabled draws over everything before it.
  If a large object mysteriously fails to occlude what it should, check both.
- **[observed] `renderOrder` cannot order across the opaque/transparent boundary.** three.js's
  `WebGLRenderList.push` partitions renderables into opaque / transmissive / transparent queues
  **primarily by `material.transparent`, with `material.transmission > 0` routed to the transmissive
  queue ahead of that check** (`three@0.185` `three.module.js` L8233-8249 —
  `if (transmission > 0) transmissive; else if (transparent === true) transparent; else opaque`), and
  `WebGLRenderer` always draws all opaque, then transmissive, then all transparent. Do not repeat the
  common shorthand that the split is "by `material.transparent` alone": true for most scenes, false
  the moment a `MeshPhysicalMaterial` with transmission enters one. `renderOrder` is only a tiebreaker
  *within* one queue. So a single `transparent: true` material is drawn after every opaque object in
  the scene no matter how negative its `renderOrder` is — including near/mid geometry with far higher
  `renderOrder` values — and if it also sets `depthTest: false`, it paints over all of them
  unconditionally, with no error and a fully green build. This cost SOLAR FRONTIER a full run: a
  `renderOrder: -900` additive starfield painted stars across a `renderOrder: -800` planet and washed
  out a `renderOrder: 0` hull. **A far-layer/renderOrder policy is only coherent while every
  participating material is in the same queue** — assert it in a unit test, don't just comment it.
  The trap is that `transparent: true` looks like the flag you need for blending. It is not:
  `WebGLState.setMaterial` suppresses blending only when `material.blending === NormalBlending` **and**
  `material.transparent === false`, so additive/multiply/custom blending works fine with
  `transparent: false`. `transparent` is a queue-assignment flag. Only order-dependent alpha-over
  blending genuinely needs the transparent queue — and such a material cannot participate in a
  renderOrder ladder at all.
  **Symptom to recognise:** a points/particle field with `depthTest: false` bleeding through solid
  geometry it should sit behind. Check `material.transparent` on every layer member before suspecting
  the `renderOrder` values. **Fix:** put every layer member in the same queue (drop `transparent: true`
  and get soft edges from `blending` plus a fragment-shader alpha `discard`, which three.js applies
  independent of queue membership), or give the layer its own render pass with the depth buffer cleared
  between passes if it genuinely needs to be transparent.
- **[observed] `GodRaysEffect` only makes shafts where a *depth-writing* occluder is near the light
  on screen.** It copies the main scene's depth into its light target, renders the sun mesh into that
  target without clearing, then radially smears the result — so an object casts a god-ray shaft if and
  only if **all** of: it wrote to the main scene's depth buffer; it overlaps the projected light disc
  on screen (within the radial-smear neighbourhood of the light's NDC position); it is nearer than the
  light in that copied depth; and the composer path feeding the effect a main-scene depth texture is
  actually enabled. Depth-write alone is necessary, not sufficient. A far layer with
  `depthWrite: false` fails the first condition and so casts none, ever. An unoccluded light
  disc radially smeared is a smooth glow indistinguishable from bloom; no `density`/`decay`/`weight`/
  `exposure` value creates a shaft. Check for an occluder before tuning. Related: `GodRaysEffect.update`
  sets `lightSource.material.depthWrite = false` after its pass and does **not** restore the prior
  value, so your sun's authored material flags stop matching its runtime state after frame one.
- **[observed] Fill light is `colour × intensity` — a near-black colour caps the contribution
  no matter how high the intensity goes.** SOLAR FRONTIER spent three consecutive runs raising
  `ambientLight`/`hemisphereLight` intensities to stop a hull rendering as a flat silhouette, while
  leaving the light colours at `#0d1524` (ambient) and `#1c3350`/`#04060a` (hemisphere sky/ground).
  `#0d1524` is linear RGB ≈ (0.006, 0.011, 0.027); multiplied by intensity 0.7 it contributes
  essentially nothing. Every "fix" was mathematically incapable of working, and each one looked like
  a regression rather than a no-op. Atmospheric, moody light colours are the right *artistic* choice
  and a trap for *debugging*: when a surface reads black, compute the actual linear contribution
  (`colour_linear × intensity`) before touching the intensity again.
- **Colour management.** `outputColorSpace = SRGBColorSpace` and a tone-mapping choice
  (ACES Filmic for cinematic) are load-bearing for the look, not polish. Set them once at
  renderer creation.
- **`InstancedMesh` for anything appearing more than a dozen times.** Per-instance colour
  and transform, with LODs. Thousands of individual `Mesh` objects will not hold budget.
- **Dispose explicitly.** Geometries, materials and render targets are not garbage-collected
  from the GPU. Dispose on unmount or leak VRAM until the context dies.
- **Heavy meshing belongs in a Web Worker**, transferred via `ArrayBuffer`. Generating
  geometry on the main thread produces a visible hitch no averaging will hide.
- **three deprecations move fast.** `THREE.Clock` is deprecated in favour of `THREE.Timer`;
  check whether a deprecation warning is yours or your dependency's before chasing it.

## Babylon.js

- `NodeMaterial` graphs are assets, not code — version them alongside meshes.
- Prefer `AssetContainer` for scene composition so teardown is a single call.
- IBL/HDR environment textures dominate the asset budget; compress and mip them.
- `scene.freezeActiveMeshes()` / material freezing for static geometry.

## PlayCanvas

- Engine-only vs Editor workflows diverge sharply; pick one and stay in it.
- Script attributes are the designer-tunable surface — don't hardcode values in scripts.

## Phaser (2D)

- Texture atlases, not individual images; watch the texture-unit ceiling.
- Arcade physics is not deterministic across frame rates — fix the timestep.
- Scene lifecycle (`preload`/`create`/`update`) leaks listeners if you don't clean up in
  `shutdown`.

## Asset delivery (all engines)

- glTF/GLB with Draco or meshopt; KTX2/Basis for textures. Never ship raw PNG texture sets.
- Persist large assets in IndexedDB rather than re-fetching; version the cache key.
- Stream progressively — first playable content should not wait on the whole bundle.
- Generate assets at **build time** and serve them static. A runtime dependency on an
  asset-generation service means the game only runs where that service is reachable.

## Instant fails

- `setInterval`/`setTimeout` as the render loop.
- Allocation inside the render loop.
- Per-frame React state updates.
- Unseeded RNG in simulation or worldgen.
- A perf or "it renders fine" claim with no capture evidence.
