# Glossary

Domain terms used across FABLE-HARNESS's agents/skills. Seeded and extended by `discovery-researcher` and `strategy-author`.

- **Run** — one invocation of `/run`, tracked under `.fable/<run_id>/`.
- **Stage** — one step of a run's lifecycle (generate → judge → verify → missability → finalize).
- **Verdict** — the outcome of a judge/verifier check: `pass` | `pass-with-notes` | `reject` (CONSTITUTION.md N4).
- **Reflexion** — a bounded, single retry-with-critique for a failed stage (N3).
- **Taxonomy floor** — the minimum artifact (e.g. a changelog entry) every request produces, even a trivial one.
- **Fable-approval token** — the single-use file (`.fable/fable-approval.token`) that gates the one path to Fable-5 (N2).
- **Handoff envelope** — a JSON file under `.fable/<run_id>/handoffs/` used for file-mediated cross-session coordination between independent `claude --worktree` sessions.
