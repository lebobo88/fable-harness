# Smoke tests for healthcheck.ps1. No external test framework dependency (repo has none
# installed today - Pester is not present), so this is a plain assertion script matching the
# dependency-free style already used by the hook scripts in this repo.
#
# Run with: pwsh -NoProfile -File .claude/scripts/healthcheck.tests.ps1
# Exits non-zero if any assertion fails.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptUnderTest = Join-Path $here 'healthcheck.ps1'
$failures = @()

function Assert-True($condition, $message) {
    if (-not $condition) {
        $script:failures += $message
        Write-Output "  [FAIL] $message"
    } else {
        Write-Output "  [OK]   $message"
    }
}

function New-Fixture {
    param([string]$Name)
    $fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "fable-healthcheck-test-$Name-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.claude/hooks') -Force | Out-Null
    return $fixtureRoot
}

function Write-ConstitutionFixture {
    param([string]$Root, [bool]$MatchingHash = $true)
    $constitutionPath = Join-Path $Root 'CONSTITUTION.md'
    'Some constitution content.' | Set-Content -Path $constitutionPath -NoNewline
    $realHash = (Get-FileHash -Path $constitutionPath -Algorithm SHA256).Hash.ToLower()
    $hashToWrite = if ($MatchingHash) { $realHash } else { '0' * 64 }
    $hashToWrite | Set-Content -Path (Join-Path $Root 'CONSTITUTION.sha256') -NoNewline
}

function Write-SettingsFixture {
    param([string]$Root, [bool]$HookScriptExists = $true)
    $hooksDir = Join-Path $Root '.claude/hooks'
    if ($HookScriptExists) {
        'Write-Output "hi"' | Set-Content -Path (Join-Path $hooksDir 'dummy-hook.ps1')
    }
    $settings = @{
        hooks = @{
            SessionStart = @(
                @{
                    hooks = @(
                        @{
                            type    = 'command'
                            command = 'pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/.claude/hooks/dummy-hook.ps1"'
                        }
                    )
                }
            )
        }
    }
    $settingsDir = Join-Path $Root '.claude'
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $settingsDir 'settings.json')
}

function Invoke-HealthCheck {
    param([string]$Root)
    $env:CLAUDE_PROJECT_DIR = $Root
    $out = & pwsh -NoProfile -File $scriptUnderTest -Json
    $exitCode = $LASTEXITCODE
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    return @{ json = ($out | ConvertFrom-Json); exitCode = $exitCode }
}

Write-Output "Test 1: valid constitution + all hooks present -> HEALTHY, exit 0"
$root1 = New-Fixture -Name 'healthy'
Write-ConstitutionFixture -Root $root1 -MatchingHash $true
Write-SettingsFixture -Root $root1 -HookScriptExists $true
$r1 = Invoke-HealthCheck -Root $root1
Assert-True ($r1.exitCode -eq 0) "exit code is 0, got $($r1.exitCode)"
Assert-True ($r1.json.constitution.valid -eq $true) "constitution reported valid"
Assert-True ($r1.json.overallHealthy -eq $true) "overallHealthy is true"
Remove-Item -Recurse -Force $root1

Write-Output "Test 2: tampered CONSTITUTION.sha256 -> UNHEALTHY, exit 1"
$root2 = New-Fixture -Name 'tampered'
Write-ConstitutionFixture -Root $root2 -MatchingHash $false
Write-SettingsFixture -Root $root2 -HookScriptExists $true
$r2 = Invoke-HealthCheck -Root $root2
Assert-True ($r2.exitCode -eq 1) "exit code is 1, got $($r2.exitCode)"
Assert-True ($r2.json.constitution.valid -eq $false) "constitution reported invalid on hash mismatch"
Remove-Item -Recurse -Force $root2

Write-Output "Test 3: missing .claude/settings.json -> exit 2"
$root3 = New-Fixture -Name 'nosettings'
Write-ConstitutionFixture -Root $root3 -MatchingHash $true
$r3 = Invoke-HealthCheck -Root $root3
Assert-True ($r3.exitCode -eq 2) "exit code is 2, got $($r3.exitCode)"
Assert-True ($r3.json.settingsFound -eq $false) "settingsFound is false"
Remove-Item -Recurse -Force $root3

Write-Output "Test 4: wired hook whose script file is missing -> UNHEALTHY, exit 1"
$root4 = New-Fixture -Name 'missinghookscript'
Write-ConstitutionFixture -Root $root4 -MatchingHash $true
Write-SettingsFixture -Root $root4 -HookScriptExists $false
$r4 = Invoke-HealthCheck -Root $root4
Assert-True ($r4.exitCode -eq 1) "exit code is 1, got $($r4.exitCode)"
Assert-True ($r4.json.overallHealthy -eq $false) "overallHealthy is false when a hook script is missing"
Remove-Item -Recurse -Force $root4

Write-Output "Test 5: unparsable .claude/settings.json (malformed JSON) -> exit 2"
$root5 = New-Fixture -Name 'unparsablesettings'
Write-ConstitutionFixture -Root $root5 -MatchingHash $true
$settingsDir5 = Join-Path $root5 '.claude'
'{ this is not valid json' | Set-Content -Path (Join-Path $settingsDir5 'settings.json')
$r5 = Invoke-HealthCheck -Root $root5
Assert-True ($r5.exitCode -eq 2) "exit code is 2, got $($r5.exitCode)"
Assert-True ($r5.json.settingsFound -eq $false) "settingsFound is false when settings.json is unparsable"
Remove-Item -Recurse -Force $root5

Write-Output "Test 6: wired command hook whose script path cannot be parsed from its command string -> fail-closed UNHEALTHY, exit 1 (regression test for reject-level fail-open bug)"
$root6 = New-Fixture -Name 'unverifiablecommandhook'
Write-ConstitutionFixture -Root $root6 -MatchingHash $true
$settings6 = @{
    hooks = @{
        SessionStart = @(
            @{
                hooks = @(
                    @{
                        # No quoted *.ps1/*.sh path embedded anywhere in this command string,
                        # so the regex-based path extraction cannot resolve a scriptPath.
                        # This MUST be treated as unverifiable/fail-closed, never as a silent pass.
                        type    = 'command'
                        command = 'echo hello-world-no-script-path-here'
                    }
                )
            }
        )
    }
}
$settingsDir6 = Join-Path $root6 '.claude'
$settings6 | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $settingsDir6 'settings.json')
$r6 = Invoke-HealthCheck -Root $root6
Assert-True ($r6.exitCode -eq 1) "exit code is 1, got $($r6.exitCode)"
Assert-True ($r6.json.overallHealthy -eq $false) "overallHealthy is false when a command hook's script cannot be verified"
Assert-True ($r6.json.hooks[0].scriptExists -eq $false) "unverifiable command hook reports scriptExists=false (fail-closed), not null"
Remove-Item -Recurse -Force $root6

Write-Output ""
if ($failures.Count -gt 0) {
    Write-Output "$($failures.Count) assertion(s) FAILED."
    exit 1
} else {
    Write-Output "All assertions passed."
    exit 0
}
