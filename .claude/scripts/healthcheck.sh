#!/usr/bin/env bash
# FABLE-HARNESS health-check CLI (POSIX mirror of healthcheck.ps1).
#
# Confirms:
#   1. CONSTITUTION.md's SHA-256 matches CONSTITUTION.sha256 (N1).
#   2. Which hooks are wired per .claude/settings.json, and whether each hook's
#      script file exists on disk.
#
# Usage: bash .claude/scripts/healthcheck.sh [--json]
#
# Exit codes:
#   0 - constitution hash valid AND every wired `command` hook's script file is
#       present AND verifiable
#   1 - constitution hash invalid/unverifiable, OR at least one wired `command`
#       hook script is missing OR its script path could not be confidently
#       parsed/verified from the command string (fail-closed: an unverifiable
#       hook is never reported as healthy)
#   2 - .claude/settings.json missing or unparsable
#
# --json output shape (parity with healthcheck.ps1 -Json):
#   { "projectDir": str, "constitution": {"checked": bool, "valid": bool, "detail": str},
#     "hooks": [{"event": str, "matcher": str, "type": str, "scriptPath": str|null,
#                "scriptExists": bool|null}], "settingsFound": bool, "overallHealthy": bool }
#
# Note: unlike session-start-attest.sh (fail-open/warn-only per N5), this CLI is an
# explicit operator/CI query and is expected to report failure via exit code.

set -uo pipefail

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
    json_mode=1
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
constitution="$project_dir/CONSTITUTION.md"
hashfile="$project_dir/CONSTITUTION.sha256"
settings="$project_dir/.claude/settings.json"

# --- 1. Constitution hash check ---------------------------------------------
constitution_checked=0
constitution_valid=0
constitution_detail=""

if [[ ! -f "$constitution" || ! -f "$hashfile" ]]; then
    constitution_detail="CONSTITUTION.md or CONSTITUTION.sha256 not found."
else
    expected="$(tr -d '[:space:]' < "$hashfile" | tr '[:upper:]' '[:lower:]')"
    actual="$(sha256sum "$constitution" 2>/dev/null | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$actual" ]]; then
        constitution_detail="Error computing hash (sha256sum unavailable?)."
    elif [[ "$actual" == "$expected" ]]; then
        constitution_checked=1
        constitution_valid=1
        constitution_detail="OK: sha256=$actual matches CONSTITUTION.sha256 (N1 satisfied)."
    else
        constitution_checked=1
        constitution_detail="MISMATCH: expected=$expected actual=$actual - CONSTITUTION.md may have been edited without regenerating CONSTITUTION.sha256 (N1)."
    fi
fi

# --- 2. Hook wiring report (requires python3 for JSON parsing, per repo convention) ---
settings_found=0
hooks_report=""
hooks_json="[]"
any_missing=0

if [[ -f "$settings" ]]; then
    settings_found=1
    hooks_report="$(python3 - "$settings" "$project_dir" <<'PYEOF'
import json, sys, os

settings_path, project_dir = sys.argv[1], sys.argv[2]
try:
    with open(settings_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"__PARSE_ERROR__:{e}")
    sys.exit(0)

import re
hooks = data.get("hooks", {})
# Fail-closed: any `command`-type hook whose script path cannot be confidently
# parsed/verified out of its command string counts as MISSING (unverifiable),
# not as "?" unknown. Only non-command hook types (e.g. `prompt`) have no script
# file to check and are reported as "?" without affecting any_missing.
any_missing = False
lines = []
json_hooks = []
for event_name, entries in hooks.items():
    for entry in entries:
        matcher = entry.get("matcher", "(all)")
        for hook in entry.get("hooks", []):
            htype = hook.get("type", "")
            script_path = ""
            exists = ""
            if htype == "command":
                cmd = hook.get("command", "")
                m = re.search(r'"([^"]*\.(?:ps1|sh))"', cmd)
                if m:
                    script_path = m.group(1).replace("$CLAUDE_PROJECT_DIR", project_dir)
                    exists = "OK" if os.path.exists(script_path) else "MISSING"
                else:
                    # command hook, but script path could not be parsed out of the
                    # command string at all -- unverifiable, so fail closed.
                    exists = "UNVERIFIABLE"
                if exists != "OK":
                    any_missing = True
            lines.append(f"{exists or '?'}\t{event_name}\t{matcher}\t{script_path}")
            json_hooks.append({
                "event": event_name,
                "matcher": matcher,
                "type": htype,
                "scriptPath": script_path or None,
                "scriptExists": (True if exists == "OK" else (False if exists in ("MISSING", "UNVERIFIABLE") else None)),
            })
print("__ANY_MISSING__:%s" % ("1" if any_missing else "0"))
print("__HOOKS_JSON__:%s" % json.dumps(json_hooks))
for l in lines:
    print(l)
PYEOF
)"
    if printf '%s' "$hooks_report" | head -1 | grep -q '^__PARSE_ERROR__'; then
        settings_found=0
    else
        any_missing="$(printf '%s\n' "$hooks_report" | sed -n '1p' | sed -E 's/^__ANY_MISSING__://')"
        hooks_json="$(printf '%s\n' "$hooks_report" | sed -n '2p' | sed -E 's/^__HOOKS_JSON__://')"
        hooks_report="$(printf '%s\n' "$hooks_report" | tail -n +3)"
    fi
fi

# --- 3. Overall verdict -------------------------------------------------------
overall_healthy=0
if [[ "$constitution_valid" == "1" && "$settings_found" == "1" && "$any_missing" == "0" ]]; then
    overall_healthy=1
fi

# --- 4. Output ----------------------------------------------------------------
if [[ "$json_mode" == "1" ]]; then
    # Parity with healthcheck.ps1 -Json: emit projectDir, constitution.checked, and
    # the full hooks array (event/matcher/type/scriptPath/scriptExists), not just the
    # summary fields, so POSIX --json output reports hook wiring in machine-readable
    # form exactly like the PowerShell implementation does.
    escaped_project_dir="$(printf '%s' "$project_dir" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '{"projectDir":"%s","constitution":{"checked":%s,"valid":%s,"detail":"%s"},"hooks":%s,"settingsFound":%s,"overallHealthy":%s}\n' \
        "$escaped_project_dir" \
        "$([[ $constitution_checked == 1 ]] && echo true || echo false)" \
        "$([[ $constitution_valid == 1 ]] && echo true || echo false)" \
        "$(printf '%s' "$constitution_detail" | sed 's/\\/\\\\/g; s/"/\\"/g')" \
        "$hooks_json" \
        "$([[ $settings_found == 1 ]] && echo true || echo false)" \
        "$([[ $overall_healthy == 1 ]] && echo true || echo false)"
else
    echo "FABLE-HARNESS health check"
    echo "=========================="
    echo ""
    echo "Constitution integrity (N1):"
    if [[ "$constitution_valid" == "1" ]]; then
        echo "  [OK]   $constitution_detail"
    else
        echo "  [FAIL] $constitution_detail"
    fi
    echo ""
    if [[ "$settings_found" != "1" ]]; then
        echo "Hooks: .claude/settings.json not found or unparsable - cannot report wiring."
    else
        echo "Wired hooks (from .claude/settings.json):"
        if [[ -z "$hooks_report" ]]; then
            echo "  (none configured)"
        else
            printf '%s\n' "$hooks_report" | while IFS=$'\t' read -r status event matcher path; do
                echo "  [$status] $event (matcher: $matcher) -> $path"
            done
        fi
    fi
    echo ""
    if [[ "$overall_healthy" == "1" ]]; then
        echo "Overall: HEALTHY"
    else
        echo "Overall: UNHEALTHY"
    fi
fi

if [[ "$settings_found" != "1" ]]; then exit 2; fi
if [[ "$overall_healthy" == "1" ]]; then exit 0; else exit 1; fi
