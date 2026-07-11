# UserPromptSubmit hook: deny direct /model fable or /advisor-to-Fable switches unless a
# single-use .fable/fable-approval.token exists (CONSTITUTION.md N2). This closes the manual
# override surfaces (surfaces 4 and 5 in ai_docs/model-routing-and-fable-policy.md) that plain
# frontmatter conventions don't cover. The token itself is written only by the AskUserQuestion
# approval flow inside an agent's turn, and is consumed (deleted) by the /plan-deep skill body
# after it starts — this hook only ever READS the token, never writes it.

$ErrorActionPreference = 'Stop'
try {
    $stdin = [Console]::In.ReadToEnd()
    $event = $stdin | ConvertFrom-Json
    $prompt = $event.prompt

    if ([string]::IsNullOrWhiteSpace($prompt)) { exit 0 }

    # Match direct attempts to switch the session/advisor model to fable. Deliberately narrow:
    # this is NOT trying to catch every phrasing of "use fable" in conversation (that's fine —
    # the model tier only actually changes via /model, /advisor, or model: fable in frontmatter,
    # none of which a plain sentence can trigger), only the literal command surfaces.
    $isFableModelSwitch = $prompt -match '(?i)^\s*/model\s+.*fable' -or
                          $prompt -match '(?i)^\s*/advisor\s+.*fable' -or
                          $prompt -match '(?i)advisorModel\s*[:=]\s*"?fable'

    if (-not $isFableModelSwitch) { exit 0 }

    $projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $tokenPath = Join-Path $projectDir '.fable\fable-approval.token'

    if (Test-Path $tokenPath) {
        # Token present — a prior AskUserQuestion approval flow authorized this. Allow through;
        # /plan-deep (or whatever consumes the token) is responsible for deleting it after use.
        exit 0
    }

    Write-Output "Refused per N2: direct switch to Claude Fable-5 requires an explicit approval — ask the harness a question first (it will use AskUserQuestion), or run /plan-deep directly, which handles the approval flow itself. Fable-5 is never auto-routed and cannot be switched to via /model or /advisor without going through that flow first."
    exit 2
} catch {
    # Fail open (N5): a bug in this script must never block the user's prompt.
    Write-Warning "[fable-harness] fable-token-gate.ps1 error (fail-open per N5): $_"
    exit 0
}
