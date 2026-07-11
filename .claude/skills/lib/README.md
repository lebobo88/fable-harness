# `.claude/skills/lib/` — shared plan rendering assets

Shared, skill-agnostic assets used by both planning skills (`plan-deep`, `plan`). Mirrors the
existing `.claude/hooks/lib/` convention (shared code, not a Claude Code primitive itself).

| file | purpose |
|---|---|
| `plan-template.html` | Full planf3-style HTML plan skeleton (used by `/plan-deep`). All sections + `{{...IMAGE:}}` slots + embedded design system. |
| `plan-template-lite.html` | Lighter variant (used by `/plan`) — drops the metadata `<details>` ceremony and Questionables. |
| `plan-images.ps1` | **Primary** local CLI (PowerShell): `extract` (prompt sheet) + `apply` (swap in `<img>`). No network, no MCP, no model call — CONSTITUTION.md **N8-safe**. |
| `plan-images.sh` | POSIX mirror of `plan-images.ps1` (perl-based). |

## The image model: manual-first

Plans are authored with **image slots**, not images. Each slot is one HTML comment inside a `<figure>`:

```html
<figure>
  <!-- {{...IMAGE: hero | the plan's end-state expressed as one clear metaphor}} -->
  <div class="fig-pending"><b>Image pending</b><span class="hint">hero.png — see prompt sheet</span></div>
  <figcaption>Human-readable caption (always present).</figcaption>
</figure>
```

- **`hero`** (before the `|`) is the target basename → the image is `‹slug›/hero.png`.
- The text **after the `|`** is the subject description → becomes the image prompt and the `<img alt>`.
- A slot with no generated PNG renders as a tidy **"image pending"** placeholder, so **the plan is fully usable with zero images**. This is the "API credits are low" path — images are optional, added whenever you like.

### Workflow

```
1. Author the plan .html (the skill does this from the template).
2. Extract the prompt sheet:
     pwsh .claude/skills/lib/plan-images.ps1 extract <plan>.html
   → writes <slug>.image-prompts.md with a ready-to-paste prompt per figure
     (subject + universal 1536x1024 style spec + target path).
3. Generate each PNG in ANY image tool (ChatGPT / Gemini / Midjourney / local SD / …),
   save it to  <plan-dir>/<slug>/<base>.png.  Generate as many or as few as you want.
4. Swap them in:
     pwsh .claude/skills/lib/plan-images.ps1 apply <plan>.html
   → each slot whose PNG now exists becomes <img src="<slug>/<base>.png" alt="…">.
     The "image pending" box auto-hides (CSS figure:has(img)). Re-runnable; only fills new ones.
```

`apply` is **idempotent** — once a slot is an `<img>` it no longer matches the slot pattern, so
re-running never double-inserts. Un-generated slots are always left untouched.

## Output location (run-aware)

- Inside an active run → `.fable/<run_id>/artifacts/<slug>.html` + sibling `.fable/<run_id>/artifacts/<slug>/`.
- Otherwise → top-level `specs/<slug>.html` + sibling `specs/<slug>/`.

## Committing

- **HTML plans** (`specs/*.html`) are durable artifacts — commit them (like planf3).
- **PNGs** (`specs/<slug>/*.png`) and the generated **`*.image-prompts.md`** sheet are optional to
  commit; they can be regenerated. `.fable/` output stays gitignored as today.

## No auto-generation (yet)

Auto-API generation (e.g. OpenAI `gpt-image-2`) is intentionally **not** wired — the pipeline is
manual-only for now. It can be added later as a third `plan-images` subcommand (`generate`) without
any template change, since the slot format already carries everything a generator needs.
