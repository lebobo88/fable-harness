# SessionStart hook: verify CONSTITUTION.md's SHA-256 against the checked-in expected hash.
# CONSTITUTION.md N1/N5: this hook is WARN-ONLY — it must never block session start, even on
# a hash mismatch or an internal script error (fail open per N5). A hard block here would risk
# bricking the harness on a trivial line-ending change.

$ErrorActionPreference = 'Stop'
try {
    $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $constitutionPath = Join-Path $projectDir 'CONSTITUTION.md'
    $hashPath = Join-Path $projectDir 'CONSTITUTION.sha256'

    if (-not (Test-Path $constitutionPath) -or -not (Test-Path $hashPath)) {
        Write-Output "[fable-harness] CONSTITUTION.md or CONSTITUTION.sha256 not found — skipping integrity check."
        exit 0
    }

    $expected = (Get-Content $hashPath -Raw).Trim()
    $actualHash = Get-FileHash -Path $constitutionPath -Algorithm SHA256
    $actual = $actualHash.Hash.ToLower()

    if ($actual -eq $expected.ToLower()) {
        $output = @{
            continue = $true
            hookSpecificOutput = @{
                hookEventName = 'SessionStart'
                additionalContext = "FABLE-HARNESS constitution integrity: OK (N1 satisfied). Active invariants: N1..N11 — see CONSTITUTION.md. Fable-5 is manual-only (N2); never write model: fable outside .claude/skills/plan-deep/SKILL.md."
            }
        }
        $output | ConvertTo-Json -Depth 5 -Compress
        exit 0
    } else {
        Write-Warning "[fable-harness] CONSTITUTION.md hash mismatch! expected=$expected actual=$actual — the constitution may have been edited without regenerating CONSTITUTION.sha256 (N1). This is a WARNING, not a block."
        exit 0
    }
} catch {
    # Fail open (N5): a bug in this script must never block session start.
    Write-Warning "[fable-harness] session-start-attest.ps1 error (ignored, fail-open per N5): $_"
    exit 0
}
