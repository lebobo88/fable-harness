#!/usr/bin/env bash
# PreToolUse/Bash hook (POSIX mirror of bash-whitelist.ps1). Whitelist-first (N6).
set -uo pipefail

input="$(cat)"
command_str="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null)"

if [[ -z "$command_str" ]]; then
    exit 0
fi

allowed_verbs="git gh ls dir cat type more less head tail wc echo pwd cd mkdir touch diff find grep rg awk sed node npm npx pnpm yarn python python3 pip pip3 pytest pwsh powershell sha256sum codex gemini agy jq tar zip unzip which where if then else elif fi for do done while case esac function select until"
denied_always="rm del rd rmdir format shutdown reboot dd"

deny_reason=""
IFS='|' read -ra parts <<< "$(printf '%s' "$command_str" | sed -E 's/&&|\|\||;/|/g')"
for sub in "${parts[@]}"; do
    sub_trimmed="$(printf '%s' "$sub" | sed -E 's/^\s+|\s+$//g')"
    head_verb="$(printf '%s' "$sub_trimmed" | awk '{print $1}')"
    for d in $denied_always; do
        if [[ "$head_verb" == "$d" ]]; then
            deny_reason="Command '$head_verb' is explicitly denied (destructive) — subcommand: '$sub_trimmed'"
            break 2
        fi
    done
    found=0
    for a in $allowed_verbs; do
        if [[ "$head_verb" == "$a" ]]; then found=1; break; fi
    done
    if [[ $found -eq 0 ]]; then
        deny_reason="Command '$head_verb' is not on the FABLE-HARNESS whitelist (N6, L4 deny-by-default) — subcommand: '$sub_trimmed'"
        break
    fi
done

if [[ -n "$deny_reason" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Refused per N6: %s"}}' "$deny_reason"
    exit 2
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
