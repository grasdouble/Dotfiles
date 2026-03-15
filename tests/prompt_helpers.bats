#!/usr/bin/env bats
# prompt_helpers.bats — Tests for toggle_option() and count_selected()
# Group H
#
# toggle_option and count_selected are now top-level functions in
# prompt_for_multiselect.sh, sourced via test_helper.

load 'test_helper'

# ── Group H: toggle_option ─────────────────────────────────────────────────

@test "H1: toggle_option sets an empty slot to true" {
    my_arr=("" "" "")
    toggle_option my_arr 1
    [[ "${my_arr[1]}" == true ]]
}

@test "H2: toggle_option sets a true slot back to empty" {
    my_arr=(true true true)
    toggle_option my_arr 0
    [[ "${my_arr[0]}" == "" ]]
}

@test "H3: toggle_option does not affect other slots" {
    my_arr=(true "" true)
    toggle_option my_arr 1
    [[ "${my_arr[0]}" == true  ]]
    [[ "${my_arr[1]}" == true  ]]
    [[ "${my_arr[2]}" == true  ]]
}

# ── Group H: count_selected ────────────────────────────────────────────────

@test "H4: count_selected returns 0 for an all-empty array" {
    my_arr=("" "" "")
    run count_selected my_arr
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "H5: count_selected returns the correct count of true values" {
    my_arr=(true "" true true "")
    run count_selected my_arr
    [ "$status" -eq 0 ]
    [ "$output" -eq 3 ]
}

@test "H6: count_selected returns n for an all-true array" {
    my_arr=(true true true true)
    run count_selected my_arr
    [ "$output" -eq 4 ]
}
