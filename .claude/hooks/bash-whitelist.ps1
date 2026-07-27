# PreToolUse/Bash hook: whitelist-first (L4) safety gate (CONSTITUTION.md N6).
# Enumerates the safe command set FABLE-HARNESS actually needs; denies everything else by
# default rather than trying to blacklist every dangerous pattern. Normalizes the command
# before matching (strip quotes/whitespace, split on shell operators) and checks each
# subcommand's head verb independently.

$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'lib\normalize-command.ps1')

    $stdin = [Console]::In.ReadToEnd()
    $event = $stdin | ConvertFrom-Json

    $command = $event.tool_input.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        # Nothing to check (shouldn't happen for a Bash tool call) — allow, fail open.
        exit 0
    }

    # The explicit allow-set. Deliberately narrow; extend here as real needs arise, not by
    # trying to guess every dangerous command up front (N6 — whitelist, not blacklist).
    $allowedVerbs = @(
        'git', 'gh', 'ls', 'dir', 'cat', 'type', 'more', 'less', 'head', 'tail', 'wc',
        'echo', 'pwd', 'cd', 'mkdir', 'touch', 'diff', 'find', 'grep', 'rg', 'awk', 'sed',
        'node', 'npm', 'npx', 'pnpm', 'yarn', 'python', 'python3', 'pip', 'pip3', 'pytest',
        'pwsh', 'powershell', 'sha256sum', 'codex', 'gemini', 'agy', 'jq', 'wc', 'tar', 'zip',
        'unzip', 'which', 'where',
        # Shell control-flow keywords, not commands - the naive splitter (see
        # normalize-command.ps1) breaks `if [ ... ]; then` etc. into separate subcommands at
        # `;`, so the trailing keyword-led fragments need to be recognized as structural, not
        # denied as unknown verbs. Found as a real bug during Phase 7 live validation.
        'if', 'then', 'else', 'elif', 'fi', 'for', 'do', 'done', 'while', 'case', 'esac',
        'function', 'select', 'until'
    )
    $deniedAlways = @('rm', 'del', 'rd', 'rmdir', 'format', 'shutdown', 'reboot', 'dd')

    $subcommands = Split-ShellCommand -Command $command
    $denyReason = $null

    foreach ($sub in $subcommands) {
        $head = Get-CommandHead -Subcommand $sub
        $headLower = $head.ToLower()
        if ($deniedAlways -contains $headLower) {
            $denyReason = "Command '$head' is explicitly denied (destructive) — subcommand: '$sub'"
            break
        }
        if (-not ($allowedVerbs -contains $headLower)) {
            $denyReason = "Command '$head' is not on the FABLE-HARNESS whitelist (N6, L4 deny-by-default) — subcommand: '$sub'. Add it to bash-whitelist.ps1's `$allowedVerbs if genuinely needed."
            break
        }
        # rm/rmdir-equivalents that slip through as flags on an allowed verb (e.g. git clean -fdx)
        if ($headLower -eq 'git' -and $sub -match '\bclean\b.*-[a-z]*f[a-z]*d') {
            $denyReason = "Refused per N6: 'git clean -fd*' is destructive and not auto-approved — subcommand: '$sub'"
            break
        }
    }

    if ($denyReason) {
        $output = @{
            hookSpecificOutput = @{
                hookEventName = 'PreToolUse'
                permissionDecision = 'deny'
                permissionDecisionReason = "Refused per N6: $denyReason"
            }
        }
        $output | ConvertTo-Json -Depth 5 -Compress
        exit 2
    }

    # Allowed — explicit allow decision (not just silent exit 0) so the reason is visible.
    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'allow'
        }
    }
    $output | ConvertTo-Json -Depth 5 -Compress
    exit 0
} catch {
    # Fail open on an internal script bug (N5) — but note this only affects THIS hook; the
    # default Claude Code permission system still applies to the Bash tool call itself.
    Write-Warning "[fable-harness] bash-whitelist.ps1 error (fail-open per N5): $_"
    exit 0
}
