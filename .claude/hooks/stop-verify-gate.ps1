# Stop hook: gates turn-ending on unverified terminal stages of the active run.
# CONSTITUTION.md N3/N4. Deterministic and cheap by design — the actual LLM verification
# work lives in the `verifier` agent + `verify-gate` skill; this hook only decides WHETHER to
# block the turn and tell Claude to go run /verify, using the exact same 3-loop ceiling that
# verify-gate.SKILL.md defines (do not let the two drift out of sync on what "3 loops" means).
#
# Run-state convention (must be honored by .claude/workflows/run.js, built in Phase 5):
#   .fable/current-run                    -> plain text, the active run_id (absent = no active run)
#   .fable/<run_id>/stages/<stage>.json   -> {stage, verify_loops, reflexion_used, last_verdict, history}
#
# MANDATORY: guard with stop_hook_active to avoid recursive re-triggering, and respect Claude
# Code's own 8-consecutive-block ceiling (we self-limit to 3 verify loops, well under that).

$ErrorActionPreference = 'Stop'
try {
    $stdin = [Console]::In.ReadToEnd()
    $event = $stdin | ConvertFrom-Json

    if ($event.stop_hook_active -eq $true) {
        # Already in a forced-continuation loop from a previous Stop-hook block. Do not
        # re-block — let it end. Claude Code's own 8-consecutive-block ceiling is the backstop;
        # we don't want to be the hook that pushes toward it unnecessarily.
        exit 0
    }

    $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $currentRunPath = Join-Path $projectDir '.fable\current-run'

    if (-not (Test-Path $currentRunPath)) {
        # No active run — nothing to gate. Most turns (chat, exploration, small edits outside
        # a /run invocation) have no active run and this hook is a no-op.
        exit 0
    }

    $runId = (Get-Content $currentRunPath -Raw).Trim()
    $stagesDir = Join-Path $projectDir ".fable\$runId\stages"

    if (-not (Test-Path $stagesDir)) {
        exit 0
    }

    $unverifiedStage = $null
    $escalatedStage = $null

    Get-ChildItem -Path $stagesDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
        $stage = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $verdict = $stage.last_verdict
        $loops = if ($null -ne $stage.verify_loops) { $stage.verify_loops } else { 0 }

        $isCleared = ($verdict -eq 'pass' -or $verdict -eq 'pass-with-notes')
        if (-not $isCleared) {
            if ($loops -ge 3) {
                # Already escalated per N3 — verify-gate/verifier already surfaced this to the
                # human. Do not re-block the turn on something already escalated.
                $script:escalatedStage = $stage.stage
            } else {
                $script:unverifiedStage = $stage.stage
            }
        }
    }

    if ($null -ne $unverifiedStage) {
        Write-Output "Refused per N3/N4: stage '$unverifiedStage' of run '$runId' has not yet been verified (or was rejected and has not exhausted its retry loops). Run /verify before ending this turn."
        exit 2
    }

    # Either everything is cleared, or the only remaining failures have already been escalated
    # to the human (verify_loops >= 3) — do not trap the human in an endless Stop-hook loop.
    exit 0
} catch {
    # Fail open (N5): a bug in this hook must never block the user from ending their turn.
    Write-Warning "[fable-harness] stop-verify-gate.ps1 error (fail-open per N5): $_"
    exit 0
}
