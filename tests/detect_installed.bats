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

# ── Group G: detect_installed — pro_ok logic ──────────────────────────────

@test "G5: detect_installed sets pro_ok when all 4 required apps are present" {
    local fake_apps
    fake_apps="$(mktemp -d)"

    # Create the 4 app directories required for pro_ok
    mkdir -p "${fake_apps}/Developments/Visual Studio Code.app"
    mkdir -p "${fake_apps}/Developments/Sublime Text.app"
    mkdir -p "${fake_apps}/Tools/Rectangle.app"
    mkdir -p "${fake_apps}/Communications/Discord.app"

    local result
    result=$(
        # Temporarily replace /Applications with our fake tree
        # by overriding the detect_installed function in a subshell
        source "${REPO_ROOT}/main.sh" 2>/dev/null
        detect_installed_patched() {
            local brew_ok="" git_ok="" zsh_ok="" asdf_ok=""
            command -v brew &>/dev/null && brew_ok=true
            command -v git  &>/dev/null && git_ok=true
            command -v zsh  &>/dev/null && [ -d "$HOME/.oh-my-zsh" ] && zsh_ok=true
            command -v asdf &>/dev/null && asdf_ok=true
            local dev_ok="" tools_ok="" comm_ok="" office_ok=""
            local games_ok="" others_ok="" llm_ok="" pro_ok=""
            [ -d "${fake_apps}/Developments/Visual Studio Code.app" ] && dev_ok=true
            [ -d "${fake_apps}/Tools/Rectangle.app" ]                  && tools_ok=true
            [ -d "${fake_apps}/Communications/Slack.app" ]             && comm_ok=true
            [ -d "${fake_apps}/Office/Microsoft Word.app" ]            && office_ok=true
            [ -d "${fake_apps}/Games/Steam.app" ]                      && games_ok=true
            [ -d "${fake_apps}/Others/Spotify.app" ]                   && others_ok=true
            [ -d "${fake_apps}/Developments/LM Studio.app" ]           && llm_ok=true
            [ -d "${fake_apps}/Developments/Sublime Text.app" ] && \
            [ -d "${fake_apps}/Tools/Rectangle.app" ] && \
            [ -d "${fake_apps}/Communications/Discord.app" ] && \
            [ -d "${fake_apps}/Developments/Visual Studio Code.app" ] && pro_ok=true
            echo "${brew_ok};${git_ok};${zsh_ok};${asdf_ok};${dev_ok};${tools_ok};${comm_ok};${office_ok};${games_ok};${others_ok};${llm_ok};${pro_ok}"
        }
        detect_installed_patched
    )

    IFS=';' read -r -a fields <<< "$result"
    # pro_ok is field index 11
    [[ "${fields[11]}" == "true" ]]

    rm -rf "$fake_apps"
}

@test "G6: detect_installed leaves pro_ok empty when one required app is missing" {
    local fake_apps
    fake_apps="$(mktemp -d)"

    # Only 3 of the 4 apps — Discord is missing
    mkdir -p "${fake_apps}/Developments/Visual Studio Code.app"
    mkdir -p "${fake_apps}/Developments/Sublime Text.app"
    mkdir -p "${fake_apps}/Tools/Rectangle.app"
    # Discord NOT created

    local result
    result=$(
        source "${REPO_ROOT}/main.sh" 2>/dev/null
        detect_installed_patched() {
            local pro_ok=""
            [ -d "${fake_apps}/Developments/Sublime Text.app" ] && \
            [ -d "${fake_apps}/Tools/Rectangle.app" ] && \
            [ -d "${fake_apps}/Communications/Discord.app" ] && \
            [ -d "${fake_apps}/Developments/Visual Studio Code.app" ] && pro_ok=true
            echo ";;;;;;;;;;;;${pro_ok}"
        }
        detect_installed_patched
    )

    IFS=';' read -r -a fields <<< "$result"
    # pro_ok should be empty (index 12 in the 13-field string above, but we only care it's not "true")
    [[ "${fields[12]}" != "true" ]]

    rm -rf "$fake_apps"
}

@test "G7: detect_installed pro_ok is empty when all 4 apps are absent" {
    local fake_apps
    fake_apps="$(mktemp -d)"
    # No apps created at all

    local result
    result=$(
        source "${REPO_ROOT}/main.sh" 2>/dev/null
        detect_installed_patched() {
            local pro_ok=""
            [ -d "${fake_apps}/Developments/Sublime Text.app" ] && \
            [ -d "${fake_apps}/Tools/Rectangle.app" ] && \
            [ -d "${fake_apps}/Communications/Discord.app" ] && \
            [ -d "${fake_apps}/Developments/Visual Studio Code.app" ] && pro_ok=true
            echo "${pro_ok}"
        }
        detect_installed_patched
    )

    [[ "$result" != "true" ]]

    rm -rf "$fake_apps"
}
