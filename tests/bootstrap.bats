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
    # Create a temp empty dir to use as PATH, ensuring git is not found
    local empty_path
    empty_path=$(mktemp -d)

    # Run bootstrap with an empty PATH so git is not on PATH
    run /bin/bash -c "PATH='${empty_path}' /bin/bash '${BOOTSTRAP}'" < /dev/null 2>&1 || true

    rm -rf "$empty_path"

    # The script should mention git is required and exit non-zero
    [[ "$output" == *"git is required"* ]]
    [[ "$status" -ne 0 ]]
}

@test "I2: bootstrap.sh detects existing repo and runs git pull (no clone)" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create a fake .git directory to simulate existing repo
    mkdir -p "${tmpdir}/.git"

    # Stub git and bash so no real network calls happen
    git_calls=""
    bash_calls=""

    # Pipe empty stdin so the non-interactive path is taken (skips read prompt)
    run bash -c "
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
    " < /dev/null 2>&1 || true

    # Should have called git pull, not git clone
    [[ "$output" == *"pulling latest"* || "$output" == *"GIT:-C"* || "$output" == *"pull"* ]]
    [[ "$output" != *"Cloning"* ]]

    rm -rf "$tmpdir"
}
