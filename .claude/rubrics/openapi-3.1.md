# Rubric: OpenAPI 3.1 / AsyncAPI 3 contract stability

Applies to: interface/contract artifacts from `api-designer.md` (§4.7).

## Checks

1. Every route/event has an explicit versioning and backward-compatibility statement.
2. Every route/event has an explicit error contract (status codes / error event schemas), not left to "standard errors."
3. Auth, rate-limit, idempotency, and retry semantics are stated per route/event where relevant, not assumed.
4. The contract is internally consistent with any `data-modeler.md` schema/event-catalog artifacts already produced for the same run (cross-check by section reference).
5. Breaking changes (if any) are flagged explicitly with a migration note, never silent.

## Verdict mapping

- `pass`: all 5 checks satisfied.
- `pass-with-notes`: checks 1-2 satisfied, 3-5 have minor gaps.
- `reject`: missing versioning/compat statement, missing error contract, or a silent breaking change.
