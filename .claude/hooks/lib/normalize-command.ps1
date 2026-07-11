# Shared helper: normalize a shell command string before whitelist matching.
# Strips surrounding quotes, collapses whitespace, lowercases nothing (commands can be
# case-sensitive on POSIX), and splits on shell operators so each subcommand is checked
# independently. Mirrors the "normalize before matching" technique used in this harness's
# research (cross-platform .ps1/.sh hook pairs with regex command-normalization).

function Split-ShellCommand {
    param([string]$Command)
    # Split on &&, ||, |, ; — the common shell chaining operators. QUOTE-AWARE: characters
    # inside single or double quotes are never treated as operators, even if they look like
    # one (e.g. a grep pattern containing a literal `|`). Found as a real bug during Phase 7
    # live validation: `grep -n "foo\|bar" file` was incorrectly split at the `|` inside the
    # quoted regex and denied. This is intentionally still not a full shell parser (no nested
    # quote-escaping, no backtick/$() awareness) - it errs toward over-splitting outside of
    # quotes, which is safe for a whitelist, while now respecting the one quote-related
    # false-positive class actually observed.
    $parts = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inSingleQuote = $false
    $inDoubleQuote = $false
    $i = 0
    while ($i -lt $Command.Length) {
        $ch = $Command[$i]
        if ($ch -eq "'" -and -not $inDoubleQuote) { $inSingleQuote = -not $inSingleQuote; [void]$current.Append($ch); $i++; continue }
        if ($ch -eq '"' -and -not $inSingleQuote) { $inDoubleQuote = -not $inDoubleQuote; [void]$current.Append($ch); $i++; continue }
        if (-not $inSingleQuote -and -not $inDoubleQuote) {
            if ($Command.Substring($i, [Math]::Min(2, $Command.Length - $i)) -eq '&&' -or
                $Command.Substring($i, [Math]::Min(2, $Command.Length - $i)) -eq '||') {
                $parts.Add($current.ToString()); $current.Clear() | Out-Null; $i += 2; continue
            }
            if ($ch -eq '|' -or $ch -eq ';') {
                $parts.Add($current.ToString()); $current.Clear() | Out-Null; $i++; continue
            }
        }
        [void]$current.Append($ch)
        $i++
    }
    $parts.Add($current.ToString())
    return $parts | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

function Get-CommandHead {
    param([string]$Subcommand)
    $trimmed = $Subcommand.Trim()
    # Strip a leading env-var assignment prefix like FOO=bar cmd (rare but seen in the wild).
    $trimmed = $trimmed -replace '^[A-Za-z_][A-Za-z0-9_]*=\S+\s+', ''
    $tokens = $trimmed -split '\s+'
    if ($tokens.Length -eq 0) { return '' }
    return $tokens[0]
}
