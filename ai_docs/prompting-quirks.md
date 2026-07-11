# General prompting best practices (offline grounding — verified against platform.claude.com prompting docs)

These apply across all agents/skills in FABLE-HARNESS regardless of model tier.

- **XML tag structuring**: wrap individual examples in `<example>` tags (`<examples>` for multiple); 3-5 examples is the sweet spot for few-shot guidance.
- **Long-context prompts (20k+ tokens)**: put long documents/data near the top of the prompt, above instructions; put the query at the very end — this improved response quality by up to 30% in Anthropic's own tests on complex multi-document inputs. Relevant to any agent reading a large spec/codebase context before acting.
- **Prefilled assistant messages on the last turn are no longer supported** (all 4.6+/Fable/Mythos models — 400 error). Don't design any agent/skill around prefill continuation tricks; use Structured Outputs, direct no-preamble instructions, or move continuations into the user message instead.
- **Multi-session agentic work**: use git itself as a state-tracking mechanism (commits/log as checkpoints) plus structured JSON files (`.fable/<run_id>/*.json`) for state and unstructured text for progress notes — exactly the pattern FABLE-HARNESS's `.fable/` run-state directory already implements.
- **Model-specific quirks for Fable-5 and Sonnet-5** are documented in `model-routing-and-fable-policy.md` — consult that file, not this one, before writing any agent/skill that targets a specific tier.

## Anthropic's own model-tier guidance (informing FABLE-HARNESS's tier table)

- Route cheap/routine tasks to Haiku for cost control.
- Sonnet is the general-purpose default for most agentic/coding work.
- Opus is reserved for the hardest reasoning, judging, and architecture tasks.
- Fable-5 (long-horizon reasoning, Anthropic API only) is reserved for exceptionally deep, structured work — and per FABLE-HARNESS's own policy, only ever manual or explicitly user-approved. See `model-routing-and-fable-policy.md`.
