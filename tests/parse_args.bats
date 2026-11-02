#!/usr/bin/env bats
# parse_args.bats — Tests for parse_args() and has_cli_args()
# Groups A and B

load 'test_helper'

# Reset state before each test
setup() {
    DRY_RUN=false
    DOCTOR_MODE=false
    UPDATE_MODE=false
    CLI_SELECTED=("" "" "" "")
}

# ── Group A: parse_args ────────────────────────────────────────────────────

@test "A1: --dry-run sets DRY_RUN=true" {
    parse_args --dry-run
    [[ "$DRY_RUN" == true ]]
}

@test "A2: --doctor sets DOCTOR_MODE=true" {
    parse_args --doctor
    [[ "$DOCTOR_MODE" == true ]]
}

@test "A3: --update enables update mode" {
    parse_args --update
    [[ "$UPDATE_MODE" == true ]]
}

@test "A4: core flags set only the four base components" {
    parse_args --brew --git --zsh --asdf
    [[ "${CLI_SELECTED[0]}" == true ]]
    [[ "${CLI_SELECTED[1]}" == true ]]
    [[ "${CLI_SELECTED[2]}" == true ]]
    [[ "${CLI_SELECTED[3]}" == true ]]
    [[ "${#CLI_SELECTED[@]}" -eq 4 ]]
}

@test "A5: --profile=core selects all four base components" {
    parse_args --profile=core
    for index in 0 1 2 3; do
        [[ "${CLI_SELECTED[index]}" == true ]]
    done
    [[ "${#CLI_SELECTED[@]}" -eq 4 ]]
}

# ── Group B: has_cli_args ──────────────────────────────────────────────────

@test "B1: has_cli_args returns 1 when no args selected" {
    # CLI_SELECTED is all empty from setup()
    run has_cli_args
    [ "$status" -eq 1 ]
}

@test "B2: has_cli_args returns 0 when at least one arg is set" {
    parse_args --brew
    run has_cli_args
    [ "$status" -eq 0 ]
}
