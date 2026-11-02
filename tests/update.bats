#!/usr/bin/env bats
# update.bats — Tests for non-Homebrew update behavior.

load 'test_helper'

setup() {
    local root
    root="$(mktemp -d)"
    export update_test_root="$root"
    export HOME="${root}/home"
    export DOTFILE_PATH="${root}/repo"
    mkdir -p "$HOME" "${DOTFILE_PATH}/config/asdf"
    printf 'nodejs 20.0.0\npnpm 9.0.0\njava adoptopenjdk-11.0.27+6\n' > "${DOTFILE_PATH}/config/asdf/tool-versions"
    printf 'neovim\n' > "${DOTFILE_PATH}/config/asdf/default-npm-packages"
    DRY_RUN=false
    INSTALL_RESULTS=()
    step=0
    numberStep=1
    LOG_FILE=/dev/null

    asdf() {
        case "$1 $2" in
            'plugin update') return 0 ;;
            'latest nodejs') printf '26.8.1\n' ;;
            'latest pnpm') printf '12.6.0\n' ;;
            'install java') return 0 ;;
            install\ *) printf '%s\n' "$*" >> "${HOME}/asdf-installs" ;;
            *) return 1 ;;
        esac
    }
    npm() { printf '%s\n' "$*" >> "${HOME}/npm-installs"; }
    nvim() { printf '%s\n' "$*" > "${HOME}/nvim-update-args"; }
    uname() { printf 'Darwin\n'; }
    curl() { printf 'font-data' > "$2"; }
}

teardown() {
    rm -rf "$update_test_root"
}

@test "updateNonBrew updates tracked ASDF versions and declared npm packages" {
    updateNonBrew

    [ "${INSTALL_RESULTS[0]}" = "ok|Non-Homebrew updates" ]
    [[ "$(cat "${DOTFILE_PATH}/config/asdf/tool-versions")" == *$'nodejs 26.8.1'* ]]
    [[ "$(cat "${DOTFILE_PATH}/config/asdf/tool-versions")" == *$'pnpm 12.6.0'* ]]
    [[ "$(cat "${DOTFILE_PATH}/config/asdf/tool-versions")" == *$'java adoptopenjdk-11.0.27+6'* ]]
    [ "$(cat "${HOME}/npm-installs")" = "install --global neovim@latest" ]
    [ -f "${HOME}/Library/Fonts/Droid Sans Mono for Powerline Nerd Font Complete.otf" ]
    [[ "$(cat "${HOME}/nvim-update-args")" == *"+Lazy! sync +MasonToolsUpdateSync +qa"* ]]
}
