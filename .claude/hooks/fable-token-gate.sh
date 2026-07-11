#!/usr/bin/env bash
# UserPromptSubmit hook (POSIX mirror of fable-token-gate.ps1). Enforces N2.
set -uo pipefail

input="$(cat)"
prompt="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("prompt",""))' 2>/dev/null)"

if [[ -z "$prompt" ]]; then exit 0; fi

is_switch=0
if printf '%s' "$prompt" | grep -qiE '^\s*/model\s+.*fable'; then is_switch=1; fi
if printf '%s' "$prompt" | grep -qiE '^\s*/advisor\s+.*fable'; then is_switch=1; fi
if printf '%s' "$prompt" | grep -qiE 'advisorModel\s*[:=]\s*"?fable'; then is_switch=1; fi

if [[ $is_switch -eq 0 ]]; then exit 0; fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
token_path="$project_dir/.fable/fable-approval.token"

if [[ -f "$token_path" ]]; then
    exit 0
fi

echo "Refused per N2: direct switch to Claude Fable-5 requires explicit approval first (AskUserQuestion flow, or run /plan-deep directly). Fable-5 is never auto-routed."
exit 2
