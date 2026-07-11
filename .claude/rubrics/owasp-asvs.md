# Rubric: OWASP ASVS-aligned security review stability

Applies to: security artifacts from `security-reviewer.md` (§4.9, plus its absorbed §4.15/§4.16 security concerns).

## Checks

1. A threat model exists identifying trust boundaries and actors (not just "we use HTTPS").
2. Authn/authz model states least-privilege explicitly, per role/actor.
3. Data classification is explicit for any new/changed data (public/internal/confidential/restricted) with a stated handling rule for each class.
4. Any new dependency or third-party call is noted for supply-chain/provenance risk (SBOM-relevant).
5. Every identified risk has a stated mitigation or an explicit "accepted risk" note with an owner — no unmitigated, unacknowledged risk.

## Verdict mapping

- `pass`: all 5 checks satisfied.
- `pass-with-notes`: checks 1-2 satisfied, 3-5 have minor gaps.
- `reject`: missing threat model, missing authz least-privilege statement, or an unmitigated/unacknowledged risk.
