#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Manual image pipeline for FABLE-HARNESS planf3-style HTML plans. Local-only, no network,
  no MCP, no model call (CONSTITUTION.md N8-safe). Two subcommands:

    extract <plan.html>   Emit a copy-paste image-prompt sheet (<slug>.image-prompts.md)
                          from the {{...IMAGE: base | subject}} slots in the plan.
    apply   <plan.html>   For each slot whose PNG now exists in the sibling <slug>/ folder,
                          swap the comment for an <img> tag. Idempotent / re-runnable.

  Workflow (low-credit / manual): author plan -> extract -> generate PNGs in any external
  image tool, save to <slug>/<base>.png -> apply -> open the .html in a browser.
  A slot left ungenerated stays a graceful "image pending" placeholder; the plan is fully
  usable with zero images.

.EXAMPLE
  pwsh .claude/skills/lib/plan-images.ps1 extract specs/my-plan.html
  pwsh .claude/skills/lib/plan-images.ps1 apply   specs/my-plan.html
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet('extract', 'apply')][string]$Command,
  [Parameter(Mandatory, Position = 1)][string]$Plan
)

$ErrorActionPreference = 'Stop'

# Universal per-image style spec (garland squad convention) appended to every prompt.
$StyleSpec = '1536x1024, high quality, minimal professional engineering-diagram style, clean flat vector look, generous whitespace, single accent color, <10 words of embedded text, 1-2 core concepts, legible to a software engineer.'

# Slot: <!-- {{...IMAGE: <base> | <subject>}} -->   (group1 = base, group2 = subject)
$SlotPattern = '<!--\s*\{\{\.\.\.IMAGE:\s*([^|}]+?)\s*\|\s*([\s\S]+?)\s*\}\}\s*-->'

if (-not (Test-Path -LiteralPath $Plan)) { throw "Plan file not found: $Plan" }
$planItem = Get-Item -LiteralPath $Plan
$slug     = [System.IO.Path]::GetFileNameWithoutExtension($planItem.Name)
$dir      = $planItem.DirectoryName
$imgDir   = Join-Path $dir $slug
$html     = Get-Content -LiteralPath $planItem.FullName -Raw

$matches = [regex]::Matches($html, $SlotPattern)

function HtmlAttrEscape([string]$s) {
  $s.Replace('&', '&amp;').Replace('"', '&quot;').Replace('<', '&lt;').Replace('>', '&gt;')
}

switch ($Command) {

  'extract' {
    if ($matches.Count -eq 0) { Write-Host "No {{...IMAGE:}} slots found in $($planItem.Name)."; return }
    $sheetPath = Join-Path $dir "$slug.image-prompts.md"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Image prompts - $slug")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Generate each image at the path shown, then run:  ``plan-images.ps1 apply $($planItem.Name)``")
    [void]$sb.AppendLine("Any slot left ungenerated stays a graceful ""image pending"" placeholder - the plan is fully usable without it.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Universal style spec (already appended to every prompt below):")
    [void]$sb.AppendLine("> $StyleSpec")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    $present = 0; $pending = 0
    foreach ($m in $matches) {
      $base = $m.Groups[1].Value.Trim()
      $subj = ($m.Groups[2].Value.Trim() -replace '\s+', ' ')
      $rel  = "$slug/$base.png"
      $abs  = Join-Path $imgDir "$base.png"
      $state = if (Test-Path -LiteralPath $abs) { $present++; 'PRESENT' } else { $pending++; 'PENDING' }
      [void]$sb.AppendLine()
      [void]$sb.AppendLine("## $base  →  ``$rel``  [$state]")
      [void]$sb.AppendLine('**Prompt (copy-paste):**')
      [void]$sb.AppendLine('```')
      [void]$sb.AppendLine("$subj. $StyleSpec")
      [void]$sb.AppendLine('```')
      [void]$sb.AppendLine("**alt / caption:** $subj")
    }
    Set-Content -LiteralPath $sheetPath -Value $sb.ToString() -Encoding UTF8
    Write-Host "Wrote $sheetPath"
    Write-Host "  slots: $($matches.Count)  |  present: $present  |  pending: $pending"
    Write-Host "  save PNGs to: $imgDir\<base>.png   then:  plan-images.ps1 apply $($planItem.Name)"
  }

  'apply' {
    if ($matches.Count -eq 0) { Write-Host "No unresolved {{...IMAGE:}} slots in $($planItem.Name) (nothing to apply)."; return }
    $swapped = 0; $pending = 0
    # Rebuild the HTML by replacing only slots whose PNG exists (evaluator keeps others verbatim).
    $new = [regex]::Replace($html, $SlotPattern, {
        param($m)
        $base = $m.Groups[1].Value.Trim()
        $subj = ($m.Groups[2].Value.Trim() -replace '\s+', ' ')
        $abs  = Join-Path $imgDir "$base.png"
        if (Test-Path -LiteralPath $abs) {
          $script:swapped++
          $alt = HtmlAttrEscape($subj)
          return "<img src=""$slug/$base.png"" alt=""$alt"">"
        } else {
          $script:pending++
          return $m.Value  # leave the slot untouched
        }
      })
    if ($swapped -gt 0) {
      Set-Content -LiteralPath $planItem.FullName -Value $new -Encoding UTF8
    }
    Write-Host "apply: swapped $swapped  |  still pending $pending  ($($planItem.Name))"
    if ($pending -gt 0) { Write-Host "  pending PNGs go in: $imgDir  (re-run apply after generating them)" }
  }
}
