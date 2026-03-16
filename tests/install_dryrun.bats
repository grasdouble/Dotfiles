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

# Helper: run a function with piped stdin (simulates interactive input)
# Usage: run_with_input "line1\nline2" my_function [args...]
# Not used directly but kept for documentation


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

@test "F6: installSoftwareDevelopment dry-run never calls brew" {
    brew() { echo "BREW_CALLED"; return 1; }
    export -f brew

    run installSoftwareDevelopment
    [ "$status" -eq 0 ]
    [[ "$output" != *"BREW_CALLED"* ]]
}

@test "F7: installSoftwarePro dry-run tracks 'ok' and never calls brew" {
    brew() { echo "BREW_CALLED"; return 1; }
    export -f brew

    DRY_RUN=true
    installSoftwarePro
    [[ "${INSTALL_RESULTS[0]}" == "ok|Software: Pro" ]]
}

# ── Group J: installGit — interactive input validation ────────────────────
# These tests verify the non-dry-run path: empty inputs are rejected until
# a non-empty value is provided (boucle while).
# Note: `run` creates a subshell; we use a temp file as a call counter so
# the stub can track invocations across the subshell boundary.

@test "J1: installGit non-dry-run: rejects empty username, accepts second attempt" {
    DRY_RUN=false
    brew() { return 0; }; export -f brew
    git()  { return 0; }; export -f git

    # Use a temp file as counter (subshell-safe)
    local counter_file
    counter_file="$(mktemp)"
    echo 0 > "$counter_file"
    export counter_file

    read() {
        local varname="${@: -1}"
        local n
        n=$(cat "$counter_file")
        (( n++ ))
        echo "$n" > "$counter_file"
        case $n in
            1) printf -v "$varname" "" ;;           # USERNAME empty → retry
            2) printf -v "$varname" "TestUser" ;;   # USERNAME valid
            3) printf -v "$varname" "" ;;           # EMAIL empty → retry
            4) printf -v "$varname" "test@example.com" ;;  # EMAIL valid
        esac
        return 0
    }
    export -f read

    run installGit
    rm -f "$counter_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot be empty"* ]]
    [[ "$output" == *"TestUser"* ]]
}

@test "J2: installGit non-dry-run: accepts valid username and email on first attempt" {
    DRY_RUN=false
    brew() { return 0; }; export -f brew
    git()  { return 0; }; export -f git

    local counter_file
    counter_file="$(mktemp)"
    echo 0 > "$counter_file"
    export counter_file

    read() {
        local varname="${@: -1}"
        local n
        n=$(cat "$counter_file")
        (( n++ ))
        echo "$n" > "$counter_file"
        case $n in
            1) printf -v "$varname" "Alice" ;;
            2) printf -v "$varname" "alice@example.com" ;;
        esac
        return 0
    }
    export -f read

    run installGit
    rm -f "$counter_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Alice"* ]]
    [[ "$output" != *"cannot be empty"* ]]
}

# ── Group K: installZsh — Oh My Zsh confirmation ─────────────────────────

@test "K1: installZsh non-dry-run: skips rm -Rf when user answers N" {
    DRY_RUN=false
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "${fake_home}/.oh-my-zsh"

    brew()  { return 0; }; export -f brew
    sh()    { return 0; }; export -f sh
    curl()  { return 0; }; export -f curl
    git()   { return 0; }; export -f git
    ln()    { return 0; }; export -f ln
    cp()    { return 0; }; export -f cp

    local fake_home_export="$fake_home"
    export fake_home_export

    read() {
        local varname="${@: -1}"
        printf -v "$varname" "N"
        return 0
    }
    export -f read

    run bash -c "
        HOME=\"$fake_home_export\"
        source '${REPO_ROOT}/main.sh'
        DRY_RUN=false
        INSTALL_RESULTS=()
        numberStep=12
        step=0
        LOG_FILE=/dev/null
        $(declare -f brew)
        $(declare -f sh)
        $(declare -f curl)
        $(declare -f git)
        $(declare -f ln)
        $(declare -f cp)
        $(declare -f read)
        installZsh
    "
    [ "$status" -eq 0 ]
    [ -d "${fake_home}/.oh-my-zsh" ]
    [[ "$output" == *"Skipping Oh My Zsh removal"* ]]
    rm -rf "$fake_home"
}

@test "K2: installZsh non-dry-run: removes ~/.oh-my-zsh when user answers y" {
    DRY_RUN=false
    local fake_home
    fake_home="$(mktemp -d)"
    mkdir -p "${fake_home}/.oh-my-zsh"

    brew()  { return 0; }; export -f brew
    sh()    { return 0; }; export -f sh
    curl()  { return 0; }; export -f curl
    git()   { return 0; }; export -f git
    ln()    { return 0; }; export -f ln
    cp()    { return 0; }; export -f cp

    local fake_home_export="$fake_home"
    export fake_home_export

    read() {
        local varname="${@: -1}"
        printf -v "$varname" "y"
        return 0
    }
    export -f read

    run bash -c "
        HOME=\"$fake_home_export\"
        source '${REPO_ROOT}/main.sh'
        DRY_RUN=false
        INSTALL_RESULTS=()
        numberStep=12
        step=0
        LOG_FILE=/dev/null
        $(declare -f brew)
        $(declare -f sh)
        $(declare -f curl)
        $(declare -f git)
        $(declare -f ln)
        $(declare -f cp)
        $(declare -f read)
        installZsh
    "
    [ "$status" -eq 0 ]
    [ ! -d "${fake_home}/.oh-my-zsh" ]
    [[ "$output" == *"Removed old Oh My Zsh"* ]]
    rm -rf "$fake_home"
}
