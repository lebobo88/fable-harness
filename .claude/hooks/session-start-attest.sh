#!/usr/bin/env bash
# SessionStart hook (POSIX mirror of session-start-attest.ps1). Warn-only, fail-open (N5).
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
constitution="$project_dir/CONSTITUTION.md"
hashfile="$project_dir/CONSTITUTION.sha256"

if [[ ! -f "$constitution" || ! -f "$hashfile" ]]; then
    echo "[fable-harness] CONSTITUTION.md or CONSTITUTION.sha256 not found — skipping integrity check."
    exit 0
fi

expected="$(tr -d '[:space:]' < "$hashfile")"
actual="$(sha256sum "$constitution" 2>/dev/null | awk '{print $1}')"

if [[ -z "$actual" ]]; then
    echo "[fable-harness] could not compute hash (sha256sum missing?) — skipping check, fail-open (N5)."
    exit 0
fi

if [[ "$actual" == "$expected" ]]; then
    printf '{"continue":true,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"FABLE-HARNESS constitution integrity: OK (N1 satisfied). Fable-5 is manual-only (N2)."}}'
    exit 0
else
    echo "[fable-harness] WARNING: CONSTITUTION.md hash mismatch (expected=$expected actual=$actual). Non-blocking." >&2
    exit 0
fi
