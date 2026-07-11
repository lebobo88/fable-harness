# FABLE-HARNESS health-check CLI.
#
# Confirms:
#   1. CONSTITUTION.md's SHA-256 matches the checked-in CONSTITUTION.sha256 (N1).
#   2. Which hooks are wired per .claude/settings.json, and whether each hook's
#      script file actually exists on disk (a wired-but-missing hook is a silent
#      no-op that this tool is meant to surface).
#
# Usage:
#   pwsh -NoProfile -File .claude/scripts/healthcheck.ps1            # human-readable report
#   pwsh -NoProfile -File .claude/scripts/healthcheck.ps1 -Json      # machine-readable report
#
# Exit codes:
#   0 - constitution hash valid AND every wired `command` hook's script file is
#       present AND verifiable
#   1 - constitution hash invalid/unverifiable, OR at least one wired `command`
#       hook script is missing OR its script path could not be confidently
#       parsed/verified from the command string (fail-closed: an unverifiable
#       hook is never reported as healthy)
#   2 - .claude/settings.json missing or unparsable (cannot assess hook wiring at all)
#
# Note: this CLI intentionally exits non-zero on a hash mismatch or missing hook script,
# unlike the SessionStart hook (session-start-attest.ps1), which is fail-open/warn-only
# per N5 so a bad hash never blocks a session. This tool is an explicit operator/CI query,
# not an automatic gate, so it is expected to report failure state via exit code.

param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

$result = [ordered]@{
    projectDir       = $projectDir
    constitution     = [ordered]@{
        checked = $false
        valid   = $false
        detail  = ''
    }
    hooks            = @()
    settingsFound    = $false
    overallHealthy   = $false
}

# --- 1. Constitution hash check ---------------------------------------------
try {
    $constitutionPath = Join-Path $projectDir 'CONSTITUTION.md'
    $hashPath = Join-Path $projectDir 'CONSTITUTION.sha256'

    if (-not (Test-Path $constitutionPath) -or -not (Test-Path $hashPath)) {
        $result.constitution.checked = $false
        $result.constitution.valid = $false
        $result.constitution.detail = 'CONSTITUTION.md or CONSTITUTION.sha256 not found.'
    } else {
        $expected = (Get-Content $hashPath -Raw).Trim().ToLower()
        $actual = (Get-FileHash -Path $constitutionPath -Algorithm SHA256).Hash.ToLower()
        $result.constitution.checked = $true
        $result.constitution.valid = ($actual -eq $expected)
        $result.constitution.detail = if ($result.constitution.valid) {
            "OK: sha256=$actual matches CONSTITUTION.sha256 (N1 satisfied)."
        } else {
            "MISMATCH: expected=$expected actual=$actual — CONSTITUTION.md may have been edited without regenerating CONSTITUTION.sha256 (N1)."
        }
    }
} catch {
    $result.constitution.checked = $false
    $result.constitution.valid = $false
    $result.constitution.detail = "Error computing hash: $_"
}

# --- 2. Hook wiring report ---------------------------------------------------
$settingsPath = Join-Path $projectDir '.claude/settings.json'

if (Test-Path $settingsPath) {
    $result.settingsFound = $true
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -Depth 20
        if ($settings.hooks) {
            foreach ($eventName in $settings.hooks.PSObject.Properties.Name) {
                $eventEntries = $settings.hooks.$eventName
                foreach ($entry in $eventEntries) {
                    $matcher = if ($entry.PSObject.Properties.Name -contains 'matcher') { $entry.matcher } else { '(all)' }
                    foreach ($hook in $entry.hooks) {
                        $rawCommand = if ($hook.type -eq 'command') { $hook.command } else { $null }
                        # scriptExists is fail-closed by design: for a `command` hook it starts as
                        # $false (unverified/unverifiable) rather than $null, so a hook whose script
                        # path cannot be confidently parsed out of its command string is counted as a
                        # failure (never a silent pass) toward overallHealthy. Non-`command` hook types
                        # (e.g. `prompt`) have no script file to check, so they remain $null/unknown and
                        # are intentionally excluded from the fail-closed check below.
                        $scriptExists = if ($hook.type -eq 'command') { $false } else { $null }
                        $scriptPath = $null
                        if ($rawCommand) {
                            # Extract a quoted path (e.g. "...File \"$CLAUDE_PROJECT_DIR/.claude/hooks/foo.ps1\"")
                            $m = [regex]::Match($rawCommand, '"([^"]*\.(ps1|sh))"')
                            if ($m.Success) {
                                $resolved = $m.Groups[1].Value.Replace('$CLAUDE_PROJECT_DIR', $projectDir)
                                $scriptPath = $resolved
                                $scriptExists = Test-Path $resolved
                            }
                            # else: command hook whose script path could not be parsed out of its
                            # command string — scriptExists stays $false (unverifiable = fail-closed),
                            # scriptPath stays $null so the human/JSON output can distinguish
                            # "verified missing" from "could not verify" if needed later.
                        }
                        $result.hooks += [ordered]@{
                            event        = $eventName
                            matcher      = $matcher
                            type         = $hook.type
                            scriptPath   = $scriptPath
                            scriptExists = $scriptExists
                        }
                    }
                }
            }
        }
    } catch {
        $result.settingsFound = $false
        $result.constitution.detail += " (Also: could not parse .claude/settings.json: $_)"
    }
}

# --- 3. Overall health verdict ----------------------------------------------
# Fail-closed: a `command`-type hook counts against health if its scriptExists is
# $false, which now covers BOTH "script path resolved but file is missing" AND
# "script path could not be confidently parsed/verified from the command string".
# Only non-command hook types (scriptExists -eq $null, e.g. `prompt`) are excluded
# from this check, since they have no script file to verify in the first place.
$anyMissingHookScript = @($result.hooks | Where-Object { $_.scriptExists -eq $false }).Count -gt 0
$result.overallHealthy = $result.constitution.valid -and -not $anyMissingHookScript -and $result.settingsFound

# --- 4. Output ----------------------------------------------------------------
if ($Json) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Output "FABLE-HARNESS health check"
    Write-Output "=========================="
    Write-Output ""
    Write-Output "Constitution integrity (N1):"
    if ($result.constitution.valid) {
        Write-Output "  [OK]   $($result.constitution.detail)"
    } else {
        Write-Output "  [FAIL] $($result.constitution.detail)"
    }
    Write-Output ""
    if (-not $result.settingsFound) {
        Write-Output "Hooks: .claude/settings.json not found or unparsable — cannot report wiring."
    } else {
        Write-Output "Wired hooks (from .claude/settings.json):"
        if ($result.hooks.Count -eq 0) {
            Write-Output "  (none configured)"
        }
        foreach ($h in $result.hooks) {
            $status = if ($null -eq $h.scriptExists) {
                '?'
            } elseif ($h.scriptExists) {
                'OK'
            } elseif ($h.type -eq 'command' -and -not $h.scriptPath) {
                'UNVERIFIABLE'
            } else {
                'MISSING'
            }
            Write-Output "  [$status] $($h.event) (matcher: $($h.matcher)) -> $($h.scriptPath)"
        }
    }
    Write-Output ""
    if ($result.overallHealthy) {
        Write-Output "Overall: HEALTHY"
    } else {
        Write-Output "Overall: UNHEALTHY"
    }
}

if (-not $result.settingsFound) { exit 2 }
if ($result.overallHealthy) { exit 0 } else { exit 1 }
