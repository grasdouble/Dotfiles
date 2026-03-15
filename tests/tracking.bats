#!/usr/bin/env bats
# tracking.bats — Tests for track_result(), print_summary(), print_progress()
# Groups C and D

load 'test_helper'

setup() {
    INSTALL_RESULTS=()
    numberStep=10
    step=0
}

# ── Group C: track_result + print_summary ──────────────────────────────────

@test "C1: track_result appends entries in 'status|name' format" {
    track_result "Brew" "ok"
    track_result "Git" "skip"
    track_result "Zsh" "error"
    [[ "${INSTALL_RESULTS[0]}" == "ok|Brew"    ]]
    [[ "${INSTALL_RESULTS[1]}" == "skip|Git"   ]]
    [[ "${INSTALL_RESULTS[2]}" == "error|Zsh"  ]]
}

@test "C2: print_summary counts ok/skip/error correctly" {
    track_result "Brew"   "ok"
    track_result "Git"    "ok"
    track_result "Zsh"    "skip"
    track_result "ASDF"   "error"

    run print_summary
    [ "$status" -eq 0 ]
    # Expect counts in the output line
    [[ "$output" == *"2 installed"* ]]
    [[ "$output" == *"1 skipped"*   ]]
    [[ "$output" == *"1 failed"*    ]]
}

# ── Group D: print_progress ────────────────────────────────────────────────

@test "D1: print_progress outputs a bar line" {
    numberStep=10
    step=5
    run print_progress
    [ "$status" -eq 0 ]
    [[ "$output" == *"█"* ]]
    [[ "$output" == *"5/10"* ]]
}

@test "D2: print_progress outputs full bar when step == numberStep" {
    numberStep=4
    step=4
    run print_progress
    [ "$status" -eq 0 ]
    # 30 filled blocks, 0 empty — no '░' in output
    [[ "$output" != *"░"* ]]
    [[ "$output" == *"4/4"* ]]
}

@test "D3: print_progress exits early when numberStep is 0" {
    numberStep=0
    step=0
    run print_progress
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
