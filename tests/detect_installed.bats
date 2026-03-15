#!/usr/bin/env bats
# detect_installed.bats — Tests for detect_installed()
# Group G

load 'test_helper'

# ── Group G: detect_installed ──────────────────────────────────────────────

@test "G1: detect_installed returns 12 semicolon-separated fields" {
    run detect_installed
    [ "$status" -eq 0 ]
    # Count the number of ';' separators — should be 11 (12 fields)
    local count
    count=$(echo "$output" | tr -cd ';' | wc -c | tr -d ' ')
    [ "$count" -eq 11 ]
}

@test "G2: detect_installed returns only 'true' or empty string per field" {
    run detect_installed
    [ "$status" -eq 0 ]
    # Split on ';' and check each field is 'true' or ''
    IFS=';' read -r -a fields <<< "$output"
    for field in "${fields[@]}"; do
        [[ "$field" == "true" || "$field" == "" ]] || {
            echo "Unexpected field value: '$field'"
            return 1
        }
    done
}

@test "G3: detect_installed marks brew as true when brew is available" {
    # Only run if brew is actually installed on this machine
    if ! command -v brew &>/dev/null; then
        skip "brew not installed on this machine"
    fi
    run detect_installed
    IFS=';' read -r -a fields <<< "$output"
    [[ "${fields[0]}" == "true" ]]
}

@test "G4: detect_installed marks brew as false/empty when brew is absent from PATH" {
    # Run detect_installed in a subshell with a PATH that excludes brew
    local result
    result=$(
        export PATH="/usr/bin:/bin"
        source "${REPO_ROOT}/main.sh" 2>/dev/null
        detect_installed
    )
    IFS=';' read -r -a fields <<< "$result"
    # brew field (index 0) should NOT be 'true'
    [[ "${fields[0]}" != "true" ]]
}
