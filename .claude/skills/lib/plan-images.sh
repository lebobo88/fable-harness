#!/usr/bin/env bash
# Manual image pipeline for FABLE-HARNESS planf3-style HTML plans — POSIX mirror of
# plan-images.ps1. Local-only, no network, no MCP, no model call (CONSTITUTION.md N8-safe).
#
#   extract <plan.html>   Emit <slug>.image-prompts.md from the {{...IMAGE: base | subject}} slots.
#   apply   <plan.html>   Swap each slot whose PNG exists in the sibling <slug>/ folder for an
#                         <img> tag. Idempotent / re-runnable.
#
# Requires perl (bundled with Git for Windows / standard on macOS+Linux).
set -euo pipefail

CMD="${1:-}"
PLAN="${2:-}"
if [ -z "$CMD" ] || [ -z "$PLAN" ]; then
  echo "usage: plan-images.sh {extract|apply} <plan.html>" >&2; exit 2
fi
if [ ! -f "$PLAN" ]; then echo "Plan file not found: $PLAN" >&2; exit 1; fi

STYLE='1536x1024, high quality, minimal professional engineering-diagram style, clean flat vector look, generous whitespace, single accent color, <10 words of embedded text, 1-2 core concepts, legible to a software engineer.'
dir=$(dirname "$PLAN")
base_html=$(basename "$PLAN")
slug="${base_html%.*}"
imgdir="$dir/$slug"

case "$CMD" in
  extract)
    sheet="$dir/$slug.image-prompts.md"
    STYLE="$STYLE" SLUG="$slug" IMGDIR="$imgdir" BASEHTML="$base_html" \
    perl -0777 -ne '
      binmode STDOUT, ":utf8";
      my $style=$ENV{STYLE}; my $slug=$ENV{SLUG}; my $imgdir=$ENV{IMGDIR}; my $bh=$ENV{BASEHTML};
      print "# Image prompts \x{2014} $slug\n\n";
      print "Generate each image at the path shown, then run:  `plan-images.sh apply $bh`\n";
      print "Any slot left ungenerated stays a graceful \"image pending\" placeholder \x{2014} the plan is fully usable without it.\n\n";
      print "Universal style spec (already appended to every prompt below):\n> $style\n\n---\n";
      my $n=0;
      while (/<!--\s*\{\{\.\.\.IMAGE:\s*([^|}]+?)\s*\|\s*(.+?)\s*\}\}\s*-->/gs) {
        my ($b,$s)=($1,$2); $b=~s/^\s+|\s+$//g; $s=~s/\s+/ /g;
        my $state = (-e "$imgdir/$b.png") ? "PRESENT" : "PENDING";
        print "\n## $b  \x{2192}  `$slug/$b.png`  [$state]\n";
        print "**Prompt (copy-paste):**\n```\n$s. $style\n```\n";
        print "**alt / caption:** $s\n";
        $n++;
      }
      print STDERR "slots: $n\n";
    ' "$PLAN" > "$sheet"
    echo "Wrote $sheet"
    echo "  save PNGs to: $imgdir/<base>.png   then:  plan-images.sh apply $base_html"
    ;;
  apply)
    SLUG="$slug" IMGDIR="$imgdir" \
    perl -0777 -i -pe '
      my $slug=$ENV{SLUG}; my $imgdir=$ENV{IMGDIR};
      s#(<!--\s*\{\{\.\.\.IMAGE:\s*([^|}]+?)\s*\|\s*(.+?)\s*\}\}\s*-->)#
        my ($whole,$b,$s)=($1,$2,$3); $b=~s/^\s+|\s+$//g; $s=~s/\s+/ /g;
        if (-e "$imgdir/$b.png") {
          my $alt=$s; $alt=~s/&/&amp;/g; $alt=~s/"/&quot;/g; $alt=~s/</&lt;/g; $alt=~s/>/&gt;/g;
          "<img src=\"$slug/$b.png\" alt=\"$alt\">";
        } else { $whole }
      #gse;
    ' "$PLAN"
    echo "apply done ($base_html) — slots with a matching PNG were swapped to <img>; others left pending."
    ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac
