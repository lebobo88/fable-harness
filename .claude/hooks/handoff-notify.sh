#!/usr/bin/env bash
# PostToolUse/Write hook (POSIX mirror of handoff-notify.ps1). Optional, no-op by default.
set -uo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null)"

[[ -z "$file_path" ]] && exit 0
[[ "$file_path" =~ \.fable/[^/]+/handoffs/.*\.json$ ]] || exit 0

notifier=""
if command -v wmux >/dev/null 2>&1; then notifier="wmux"
elif command -v cmux >/dev/null 2>&1; then notifier="cmux"
fi

if [[ -n "$notifier" ]]; then
    "$notifier" notify "FABLE-HARNESS: new cross-session handoff written ($(basename "$file_path"))" >/dev/null 2>&1 || true
else
    printf '\033]9;FABLE-HARNESS: new cross-session handoff written\007'
fi
exit 0
