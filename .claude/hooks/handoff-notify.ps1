# PostToolUse/Write hook: optional operator-visibility notification for file-mediated
# cross-session handoffs (see AGENTS.md's Multi-Agent Systems section and
# memory/decisions/2026-07-10-cmux-integration.md). Fires ONLY if a `wmux` or `cmux` binary
# is found on PATH; otherwise this is a complete no-op (N8 — never a forced dependency).
# Never blocks (PostToolUse can't undo a completed write anyway); always exits 0.

$ErrorActionPreference = 'Stop'
try {
    $stdin = [Console]::In.ReadToEnd()
    $event = $stdin | ConvertFrom-Json

    $filePath = $event.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

    # Only care about writes into .fable/<run_id>/handoffs/*.json — everything else is silent.
    if ($filePath -notmatch '\.fable[\\/][^\\/]+[\\/]handoffs[\\/].*\.json$') {
        exit 0
    }

    $notifier = Get-Command wmux -ErrorAction SilentlyContinue
    if (-not $notifier) { $notifier = Get-Command cmux -ErrorAction SilentlyContinue }

    if ($notifier) {
        $msg = "FABLE-HARNESS: new cross-session handoff written ($([System.IO.Path]::GetFileName($filePath)))"
        & $notifier.Source notify $msg 2>$null | Out-Null
    } else {
        # No wmux/cmux on PATH — emit a bare OSC 9 notification; harmless no-op in terminals
        # that don't understand it, and genuinely free (no process spawn) otherwise.
        $osc9 = "$([char]27)]9;FABLE-HARNESS: new cross-session handoff written$([char]7)"
        [Console]::Out.Write($osc9)
    }
    exit 0
} catch {
    # Fail open (N5) — this is a pure convenience hook, never allowed to affect the session.
    exit 0
}
