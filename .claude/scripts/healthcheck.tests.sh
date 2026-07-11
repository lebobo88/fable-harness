#!/usr/bin/env bash
# Smoke tests for healthcheck.sh (POSIX mirror of healthcheck.tests.ps1). No external test
# framework dependency (repo has no bats installed today), so this is a plain assertion
# script matching the dependency-free style already used by healthcheck.tests.ps1 and the
# hook scripts in this repo.
#
# Additionally acts as the cross-implementation parity check: every fixture below is also
# run through healthcheck.ps1 (if `pwsh` is available on PATH) and the exit code /
# overallHealthy verdict is asserted to match healthcheck.sh's verdict on the same fixture.
#
# Run with: bash .claude/scripts/healthcheck.tests.sh
# Exits non-zero if any assertion fails.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_under_test="$here/healthcheck.sh"
ps1_script="$here/healthcheck.ps1"
failures=0
have_pwsh=0
if command -v pwsh >/dev/null 2>&1; then
    have_pwsh=1
fi

assert_true() {
    # $1 = 0/1 condition (1 = true), $2 = message
    if [[ "$1" != "1" ]]; then
        failures=$((failures + 1))
        echo "  [FAIL] $2"
    else
        echo "  [OK]   $2"
    fi
}

new_fixture() {
    local name="$1"
    local root
    root="$(mktemp -d "${TMPDIR:-/tmp}/fable-healthcheck-test-${name}-XXXXXX")"
    mkdir -p "$root/.claude/hooks"
    printf '%s' "$root"
}

write_constitution_fixture() {
    # $1 = root, $2 = "true"/"false" (matching hash)
    local root="$1" matching="$2"
    printf '%s' 'Some constitution content.' > "$root/CONSTITUTION.md"
    local real_hash
    real_hash="$(sha256sum "$root/CONSTITUTION.md" | awk '{print $1}')"
    if [[ "$matching" == "true" ]]; then
        printf '%s' "$real_hash" > "$root/CONSTITUTION.sha256"
    else
        printf '%s' "0000000000000000000000000000000000000000000000000000000000000000" > "$root/CONSTITUTION.sha256"
    fi
}

write_settings_fixture() {
    # $1 = root, $2 = "true"/"false" (hook script exists)
    local root="$1" hook_exists="$2"
    if [[ "$hook_exists" == "true" ]]; then
        printf 'echo hi\n' > "$root/.claude/hooks/dummy-hook.sh"
    fi
    cat > "$root/.claude/settings.json" <<'JSONEOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/dummy-hook.sh\""
          }
        ]
      }
    ]
  }
}
JSONEOF
}

# Runs healthcheck.sh --json against $1 (fixture root); sets sh_exit and sh_json.
run_sh_healthcheck() {
    local root="$1"
    sh_json="$(CLAUDE_PROJECT_DIR="$root" bash "$script_under_test" --json)"
    sh_exit=$?
}

# Runs healthcheck.ps1 -Json against $1 (fixture root), if pwsh is available;
# sets ps1_exit and ps1_json. No-ops (leaves both unset/blank) if pwsh is unavailable.
run_ps1_healthcheck() {
    local root="$1"
    if [[ "$have_pwsh" != "1" ]]; then
        ps1_exit=""
        ps1_json=""
        return
    fi
    ps1_json="$(CLAUDE_PROJECT_DIR="$root" pwsh -NoProfile -File "$ps1_script" -Json)"
    ps1_exit=$?
}

json_get_bool() {
    # $1 = json string, $2 = python-ish dotted path expression relative to the loaded object
    python3 -c "
import json, sys
data = json.loads(sys.argv[1])
try:
    v = eval('data' + sys.argv[2])
except Exception:
    v = None
print('true' if v is True else ('false' if v is False else 'null'))
" "$1" "$2"
}

echo "Test 1: valid constitution + all hooks present -> HEALTHY, exit 0"
root1="$(new_fixture healthy)"
write_constitution_fixture "$root1" true
write_settings_fixture "$root1" true
run_sh_healthcheck "$root1"
assert_true "$([[ $sh_exit -eq 0 ]] && echo 1 || echo 0)" "sh: exit code is 0, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['constitution']['valid']") == true ]] && echo 1 || echo 0)" "sh: constitution reported valid"
assert_true "$([[ $(json_get_bool "$sh_json" "['overallHealthy']") == true ]] && echo 1 || echo 0)" "sh: overallHealthy is true"
run_ps1_healthcheck "$root1"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on healthy fixture"
fi
rm -rf "$root1"

echo "Test 2: tampered CONSTITUTION.sha256 -> UNHEALTHY, exit 1"
root2="$(new_fixture tampered)"
write_constitution_fixture "$root2" false
write_settings_fixture "$root2" true
run_sh_healthcheck "$root2"
assert_true "$([[ $sh_exit -eq 1 ]] && echo 1 || echo 0)" "sh: exit code is 1, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['constitution']['valid']") == false ]] && echo 1 || echo 0)" "sh: constitution reported invalid on hash mismatch"
run_ps1_healthcheck "$root2"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on tampered-hash fixture"
fi
rm -rf "$root2"

echo "Test 3: missing .claude/settings.json -> exit 2"
root3="$(new_fixture nosettings)"
write_constitution_fixture "$root3" true
run_sh_healthcheck "$root3"
assert_true "$([[ $sh_exit -eq 2 ]] && echo 1 || echo 0)" "sh: exit code is 2, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['settingsFound']") == false ]] && echo 1 || echo 0)" "sh: settingsFound is false"
run_ps1_healthcheck "$root3"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on missing-settings fixture"
fi
rm -rf "$root3"

echo "Test 4: wired hook whose script file is missing -> UNHEALTHY, exit 1"
root4="$(new_fixture missinghookscript)"
write_constitution_fixture "$root4" true
write_settings_fixture "$root4" false
run_sh_healthcheck "$root4"
assert_true "$([[ $sh_exit -eq 1 ]] && echo 1 || echo 0)" "sh: exit code is 1, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['overallHealthy']") == false ]] && echo 1 || echo 0)" "sh: overallHealthy is false when a hook script is missing"
run_ps1_healthcheck "$root4"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on missing-hook-script fixture"
fi
rm -rf "$root4"

echo "Test 5: unparsable .claude/settings.json (malformed JSON) -> exit 2"
root5="$(new_fixture unparsablesettings)"
write_constitution_fixture "$root5" true
printf '{ this is not valid json' > "$root5/.claude/settings.json"
run_sh_healthcheck "$root5"
assert_true "$([[ $sh_exit -eq 2 ]] && echo 1 || echo 0)" "sh: exit code is 2, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['settingsFound']") == false ]] && echo 1 || echo 0)" "sh: settingsFound is false when settings.json is unparsable"
run_ps1_healthcheck "$root5"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on unparsable-settings fixture"
fi
rm -rf "$root5"

echo "Test 6: wired command hook whose script path cannot be parsed from its command string -> fail-closed UNHEALTHY, exit 1 (regression test for reject-level fail-open bug)"
root6="$(new_fixture unverifiablecommandhook)"
write_constitution_fixture "$root6" true
cat > "$root6/.claude/settings.json" <<'JSONEOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo hello-world-no-script-path-here"
          }
        ]
      }
    ]
  }
}
JSONEOF
run_sh_healthcheck "$root6"
assert_true "$([[ $sh_exit -eq 1 ]] && echo 1 || echo 0)" "sh: exit code is 1, got $sh_exit"
assert_true "$([[ $(json_get_bool "$sh_json" "['overallHealthy']") == false ]] && echo 1 || echo 0)" "sh: overallHealthy is false when a command hook's script cannot be verified"
assert_true "$([[ $(json_get_bool "$sh_json" "['hooks'][0]['scriptExists']") == false ]] && echo 1 || echo 0)" "sh: unverifiable command hook reports scriptExists=false (fail-closed), not null"
run_ps1_healthcheck "$root6"
if [[ "$have_pwsh" == "1" ]]; then
    assert_true "$([[ $ps1_exit -eq $sh_exit ]] && echo 1 || echo 0)" "parity: ps1 exit ($ps1_exit) matches sh exit ($sh_exit) on unverifiable-command-hook fixture"
fi
rm -rf "$root6"

echo ""
if [[ "$have_pwsh" != "1" ]]; then
    echo "NOTE: pwsh not found on PATH -- cross-implementation parity assertions were skipped (sh-only assertions still ran)."
fi
echo ""
if [[ "$failures" -gt 0 ]]; then
    echo "$failures assertion(s) FAILED."
    exit 1
else
    echo "All assertions passed."
    exit 0
fi
