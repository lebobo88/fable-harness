# Codex Rubber-Duck Bridge — the concrete, deterministic contract `judge-cross-vendor.md`
# uses to get a genuine cross-vendor second opinion from OpenAI Codex CLI, no MCP involved.
# Confirmed working invocation: codex exec --sandbox read-only --skip-git-repo-check "<prompt>"
#
# Usage: pwsh -File codex-review.ps1 -RunId <run_id> -Stage <stage> -PromptPath <path to .md prompt file>
# Writes: .fable/<run_id>/verdicts/<stage>-codex.json  {verdict, issues, raw_output_path}

param(
    [Parameter(Mandatory=$true)][string]$RunId,
    [Parameter(Mandatory=$true)][string]$Stage,
    [Parameter(Mandatory=$true)][string]$PromptPath
)

$ErrorActionPreference = 'Stop'
$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$runDir = Join-Path $projectDir ".fable\$RunId"
$verdictsDir = Join-Path $runDir 'verdicts'
New-Item -ItemType Directory -Path $verdictsDir -Force | Out-Null

$rawOutputPath = Join-Path $runDir "codex-review-$Stage-raw.txt"
$verdictPath = Join-Path $verdictsDir "$Stage-codex.json"

if (-not (Test-Path $PromptPath)) {
    throw "Prompt file not found: $PromptPath"
}
$promptText = Get-Content $PromptPath -Raw

# Ask Codex to end its review with an explicit, greppable verdict line so normalization is
# reliable rather than trying to free-form-parse prose.
$fullPrompt = @"
$promptText

IMPORTANT: end your response with exactly one line in this format (no other text on that line):
VERDICT: pass|pass-with-notes|reject
"@

try {
    $raw = & codex exec --sandbox read-only --skip-git-repo-check $fullPrompt 2>&1 | Out-String
} catch {
    # Codex CLI itself failed to run (not installed, auth issue, etc). Per CONSTITUTION N4,
    # a validator that cannot validate has already failed — treat as reject, not a silent skip.
    $raw = "Codex CLI invocation failed: $_"
}

Set-Content -Path $rawOutputPath -Value $raw -NoNewline

$verdict = 'reject'
if ($raw -match '(?im)^VERDICT:\s*(pass-with-notes|pass|reject)\s*$') {
    $verdict = $matches[1].ToLower()
}

$issues = @()
foreach ($line in ($raw -split "`n")) {
    if ($line -match '^\s*[-*]\s+(.+)$') {
        $issues += $matches[1].Trim()
    }
}

$result = @{
    verdict = $verdict
    issues = $issues
    raw_output_path = $rawOutputPath
}
$result | ConvertTo-Json -Depth 5 | Set-Content -Path $verdictPath
Write-Output "Codex cross-vendor verdict for stage '$Stage': $verdict (full output: $rawOutputPath)"
