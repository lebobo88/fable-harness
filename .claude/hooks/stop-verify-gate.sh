#!/usr/bin/env bash
# Stop hook (POSIX mirror of stop-verify-gate.ps1). CONSTITUTION.md N3/N4/N5.
set -uo pipefail

input="$(cat)"
stop_active="$(printf '%s' "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(d.get("stop_hook_active", False)).lower())' 2>/dev/null)"

if [[ "$stop_active" == "true" ]]; then
    exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
current_run_file="$project_dir/.fable/current-run"

if [[ ! -f "$current_run_file" ]]; then
    exit 0
fi

run_id="$(tr -d '[:space:]' < "$current_run_file")"
stages_dir="$project_dir/.fable/$run_id/stages"

if [[ ! -d "$stages_dir" ]]; then
    exit 0
fi

unverified=""
for f in "$stages_dir"/*.json; do
    [[ -e "$f" ]] || continue
    result="$(python3 -c "
import json
with open('$f') as fh:
    s = json.load(fh)
verdict = s.get('last_verdict')
loops = s.get('verify_loops', 0)
cleared = verdict in ('pass', 'pass-with-notes')
if not cleared and loops < 3:
    print(s.get('stage', '$f'))
" 2>/dev/null)"
    if [[ -n "$result" ]]; then
        unverified="$result"
        break
    fi
done

if [[ -n "$unverified" ]]; then
    echo "Refused per N3/N4: stage '$unverified' of run '$run_id' has not yet been verified. Run /verify before ending this turn."
    exit 2
fi

exit 0
