# FABLE-HARNESS user-scope installer — merge-safe, never clobbers an existing ~/.claude setup.
#
# Background (discovered during FABLE-HARNESS planning): ~/.claude/agents and ~/.claude/skills
# are commonly WHOLE-DIRECTORY symlinks into a single owning project (e.g. pair-programmer).
# A naive "symlink our folder over theirs" install would silently destroy that project's
# install. This script instead converts a whole-directory symlink into a real directory
# containing one per-file symlink per pre-existing file (preserving every prior owner), then
# adds FABLE-HARNESS's own per-file symlinks alongside.
#
# ALWAYS run with -DryRun first. This script refuses to write anything unless -Confirm is
# also passed (a human, or the install-user-scope skill after explicit AskUserQuestion
# confirmation, must pass -Confirm deliberately — no default-to-yes anywhere).

param(
    [switch]$DryRun,
    [switch]$Confirm
)

$ErrorActionPreference = 'Stop'

$fableRoot = "H:\FABLE-HARNESS"
$fableAgentsDir = Join-Path $fableRoot '.claude\agents'
$fableSkillsDir = Join-Path $fableRoot '.claude\skills'
$userClaudeDir = Join-Path $env:USERPROFILE '.claude'
$userAgentsDir = Join-Path $userClaudeDir 'agents'
$userSkillsDir = Join-Path $userClaudeDir 'skills'
$userSettingsPath = Join-Path $userClaudeDir 'settings.json'

function Write-Plan {
    param([string]$Line)
    Write-Output "  [plan] $Line"
}

function Convert-DirSymlinkToRealDir {
    param([string]$Path, [string]$Label)
    $item = Get-Item -Path $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        Write-Plan "$Label ($Path) does not exist yet -> will create as a real directory."
        if (-not $DryRun -and $Confirm) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        return
    }
    $isSymlink = ($item.LinkType -eq 'SymbolicLink' -or $item.LinkType -eq 'Junction')
    if ($isSymlink -and $item.PSIsContainer) {
        $target = $item.Target
        Write-Plan "$Label ($Path) is a WHOLE-DIRECTORY symlink -> $target. Will convert to a real directory containing one per-file symlink per existing file in $target (preserving that project's install), then add FABLE-HARNESS's own per-file symlinks alongside."
        if (-not $DryRun -and $Confirm) {
            $existingFiles = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
            $preserved = @()
            foreach ($f in $existingFiles) {
                $preserved += @{ name = $f.Name; target = $f.FullName }
            }
            Remove-Item -Path $Path -Force  # removes only the symlink pointer itself, not $target's contents
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            foreach ($p in $preserved) {
                New-Item -ItemType SymbolicLink -Path (Join-Path $Path $p.name) -Target $p.target -Force | Out-Null
            }
            Write-Output "  [done] Preserved $($preserved.Count) existing per-file symlinks under $Path."
        }
    } elseif ($item.PSIsContainer) {
        Write-Plan "$Label ($Path) is already a real directory -> no conversion needed, will add per-file symlinks alongside existing content."
    } else {
        throw "$Label ($Path) exists but is neither a directory nor a directory symlink — refusing to touch it. Resolve manually."
    }
}

function Add-FableSymlinks {
    param([string]$SourceDir, [string]$DestDir, [string]$Label)
    Get-ChildItem -Path $SourceDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        $destPath = Join-Path $DestDir $_.Name
        if (Test-Path $destPath) {
            Write-Plan "$Label/$($_.Name) already exists at destination -> SKIP (never overwrite an existing file/symlink)."
        } else {
            Write-Plan "$Label/$($_.Name) -> will symlink to $($_.FullName)."
            if (-not $DryRun -and $Confirm) {
                New-Item -ItemType SymbolicLink -Path $destPath -Target $_.FullName -Force | Out-Null
            }
        }
    }
}

function Merge-Settings {
    Write-Plan "settings.json ($userSettingsPath): will READ-MERGE, never overwrite."
    if (-not (Test-Path $userSettingsPath)) {
        Write-Plan "  -> does not exist yet, will create with FABLE-HARNESS's availableModels + hooks only."
        if (-not $DryRun -and $Confirm) {
            $fableSettings = Get-Content (Join-Path $fableRoot '.claude\settings.json') -Raw | ConvertFrom-Json
            $fableSettings | ConvertTo-Json -Depth 10 | Set-Content $userSettingsPath
        }
        return
    }

    $existing = Get-Content $userSettingsPath -Raw | ConvertFrom-Json
    $fableSettings = Get-Content (Join-Path $fableRoot '.claude\settings.json') -Raw | ConvertFrom-Json

    # availableModels: warn on conflict, never silently override another tool's restriction.
    if ($existing.PSObject.Properties.Name -contains 'availableModels') {
        Write-Plan "  -> existing 'availableModels' found ($($existing.availableModels -join ',')) — will NOT override; if it already excludes fable, no action needed. If it includes fable, this is a CONFLICT requiring manual review (never auto-resolved)."
    } else {
        Write-Plan "  -> no existing 'availableModels' — will ADD FABLE-HARNESS's (['sonnet','opus','haiku'], excluding fable)."
    }

    # hooks: append into each event's existing array, never replace.
    Write-Plan "  -> hooks: will APPEND each FABLE-HARNESS hook entry into the corresponding event's existing array (or create the event key if absent). Never removes or reorders existing entries from other projects."

    if (-not $DryRun -and $Confirm) {
        if (-not ($existing.PSObject.Properties.Name -contains 'availableModels')) {
            $existing | Add-Member -NotePropertyName 'availableModels' -NotePropertyValue $fableSettings.availableModels -Force
        }
        if (-not ($existing.PSObject.Properties.Name -contains 'hooks')) {
            $existing | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        foreach ($eventName in $fableSettings.hooks.PSObject.Properties.Name) {
            if (-not ($existing.hooks.PSObject.Properties.Name -contains $eventName)) {
                $existing.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @() -Force
            }
            $existing.hooks.$eventName = @($existing.hooks.$eventName) + @($fableSettings.hooks.$eventName)
        }
        $existing | ConvertTo-Json -Depth 10 | Set-Content $userSettingsPath
        Write-Output "  [done] settings.json merged."
    }
}

Write-Output "=== FABLE-HARNESS user-scope install plan (DryRun=$($DryRun.IsPresent -or -not $Confirm.IsPresent), Confirm=$($Confirm.IsPresent)) ==="
Convert-DirSymlinkToRealDir -Path $userAgentsDir -Label 'agents'
Add-FableSymlinks -SourceDir $fableAgentsDir -DestDir $userAgentsDir -Label 'agents'
Convert-DirSymlinkToRealDir -Path $userSkillsDir -Label 'skills'
Add-FableSymlinks -SourceDir $fableSkillsDir -DestDir $userSkillsDir -Label 'skills'
Merge-Settings

if (-not $Confirm) {
    Write-Output "`n=== DRY RUN ONLY — nothing was written. Re-run with -Confirm to actually apply this plan. ==="
} else {
    Write-Output "`n=== Install applied. ==="
}
