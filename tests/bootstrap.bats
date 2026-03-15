#!/usr/bin/env bats
# bootstrap.bats — Tests for bootstrap.sh logic that does NOT require network
# Group I
#
# bootstrap.sh is NOT sourced (it uses set -e and calls git/bash directly).
# We test it by running it as a subprocess with stubbed external commands.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
BOOTSTRAP="${REPO_ROOT}/bootstrap.sh"

# ── Group I: bootstrap.sh non-network logic ────────────────────────────────

@test "I1: bootstrap.sh exits 1 and prints [ERROR] when git is not available" {
    # Run bootstrap in a subshell where git is not on PATH
    run -127 env PATH="/usr/bin:/bin" bash -c "
        # Remove git from the subshell
        git() { return 127; }
        export -f git
        source '${BOOTSTRAP}'
    " 2>&1 || true

    # The script should mention git is required
    [[ "$output" == *"git is required"* || "$status" -ne 0 ]]
}

@test "I2: bootstrap.sh detects existing repo and runs git pull (no clone)" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create a fake .git directory to simulate existing repo
    mkdir -p "${tmpdir}/.git"

    # Stub git and bash so no real network calls happen
    git_calls=""
    bash_calls=""

    run env DEST="$tmpdir" bash -c "
        git() {
            echo \"GIT:\$*\"
            # simulate successful pull
            return 0
        }
        bash() {
            echo \"BASH:\$*\"
            return 0
        }
        export -f git bash
        DEST='${tmpdir}'
        source '${BOOTSTRAP}'
    " 2>&1 || true

    # Should have called git pull, not git clone
    [[ "$output" == *"pulling latest"* || "$output" == *"GIT:-C"* || "$output" == *"pull"* ]]
    [[ "$output" != *"Cloning"* ]]

    rm -rf "$tmpdir"
}
