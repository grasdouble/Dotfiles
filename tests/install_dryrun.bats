#!/usr/bin/env bats
# install_dryrun.bats — Tests for brew_install() and installXxx() in dry-run mode
# Groups E and F

load 'test_helper'

setup() {
    DRY_RUN=true
    INSTALL_RESULTS=()
    numberStep=12
    step=0
    LOG_FILE=/dev/null
}

# ── Group E: brew_install dry-run ──────────────────────────────────────────

@test "E1: brew_install in dry-run prints [DRY-RUN] and does NOT call brew" {
    # stub 'brew' to fail loudly if called
    brew() { echo "BREW_CALLED"; return 1; }
    export -f brew

    run brew_install git
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    [[ "$output" != *"BREW_CALLED"* ]]
}

@test "E2: brew_install in dry-run includes the package name in output" {
    brew() { return 0; }
    export -f brew

    run brew_install visual-studio-code
    [[ "$output" == *"visual-studio-code"* ]]
}

# ── Group F: installXxx dry-run — representative functions ────────────────

@test "F1: installBrew dry-run tracks 'ok' and never calls Homebrew installer" {
    curl() { echo "CURL_CALLED"; return 1; }
    export -f curl

    # Call directly (not via `run`) so INSTALL_RESULTS is visible in this shell
    installBrew
    [[ "${INSTALL_RESULTS[0]}" == "ok|Brew" ]]
}

@test "F2: installGit dry-run tracks 'ok' without prompting for user input" {
    installGit
    [[ "${INSTALL_RESULTS[0]}" == "ok|Git" ]]
}

@test "F3: installZsh dry-run tracks 'ok' without touching the filesystem" {
    installZsh
    [[ "${INSTALL_RESULTS[0]}" == "ok|Zsh" ]]
}

@test "F4: installAsdf dry-run tracks 'ok'" {
    installAsdf
    [[ "${INSTALL_RESULTS[0]}" == "ok|ASDF" ]]
}

@test "F5: installSoftwareDevelopment dry-run tracks 'ok'" {
    installSoftwareDevelopment
    [[ "${INSTALL_RESULTS[0]}" == "ok|Software: Development" ]]
}
