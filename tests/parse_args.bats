#!/usr/bin/env bats
# parse_args.bats — Tests for parse_args() and has_cli_args()
# Groups A and B

load 'test_helper'

# Reset state before each test
setup() {
    DRY_RUN=false
    DOCTOR_MODE=false
    CLI_SELECTED=("" "" "" "" "" "" "" "" "" "" "" "")
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

@test "A3: individual flags set the correct CLI_SELECTED slot" {
    parse_args --brew --git --zsh --asdf --dev --tools --comm --office --games --others --llm --pro
    [[ "${CLI_SELECTED[0]}"  == true ]]
    [[ "${CLI_SELECTED[1]}"  == true ]]
    [[ "${CLI_SELECTED[2]}"  == true ]]
    [[ "${CLI_SELECTED[3]}"  == true ]]
    [[ "${CLI_SELECTED[4]}"  == true ]]
    [[ "${CLI_SELECTED[5]}"  == true ]]
    [[ "${CLI_SELECTED[6]}"  == true ]]
    [[ "${CLI_SELECTED[7]}"  == true ]]
    [[ "${CLI_SELECTED[8]}"  == true ]]
    [[ "${CLI_SELECTED[9]}"  == true ]]
    [[ "${CLI_SELECTED[10]}" == true ]]
    [[ "${CLI_SELECTED[11]}" == true ]]
}

@test "A4: --profile=core sets slots 0-3 only" {
    parse_args --profile=core
    [[ "${CLI_SELECTED[0]}" == true ]]
    [[ "${CLI_SELECTED[1]}" == true ]]
    [[ "${CLI_SELECTED[2]}" == true ]]
    [[ "${CLI_SELECTED[3]}" == true ]]
    [[ "${CLI_SELECTED[4]}" == "" ]]
    [[ "${CLI_SELECTED[5]}" == "" ]]
}

@test "A5: --profile=dev sets slots 0-4 only" {
    parse_args --profile=dev
    [[ "${CLI_SELECTED[0]}" == true ]]
    [[ "${CLI_SELECTED[1]}" == true ]]
    [[ "${CLI_SELECTED[2]}" == true ]]
    [[ "${CLI_SELECTED[3]}" == true ]]
    [[ "${CLI_SELECTED[4]}" == true ]]
    [[ "${CLI_SELECTED[5]}" == "" ]]
}

@test "A6: --profile=gaming sets slots 0 and 8 only" {
    parse_args --profile=gaming
    [[ "${CLI_SELECTED[0]}" == true ]]
    [[ "${CLI_SELECTED[1]}" == "" ]]
    [[ "${CLI_SELECTED[8]}" == true ]]
    [[ "${CLI_SELECTED[9]}" == "" ]]
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
