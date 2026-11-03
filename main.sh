#!/bin/bash

# ============================================================================
# Dotfiles CLI
# Usage: bash main.sh [core|list|install|remove|profiles|update|doctor]
# Base setup installs only Brew, Git, Zsh, and ASDF; apps use the Ink manager.
# ============================================================================
DRY_RUN=false
DOCTOR_MODE=false
UPDATE_MODE=false
declare -a CLI_SELECTED=("" "" "" "")  # Brew, Git, Zsh, ASDF

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run)    DRY_RUN=true ;;
            --doctor)     DOCTOR_MODE=true ;;
            --update)     UPDATE_MODE=true ;;
            --brew)       CLI_SELECTED[0]=true ;;
            --git)        CLI_SELECTED[1]=true ;;
            --zsh)        CLI_SELECTED[2]=true ;;
            --asdf)       CLI_SELECTED[3]=true ;;
            --profile=core)
                CLI_SELECTED[0]=true; CLI_SELECTED[1]=true
                CLI_SELECTED[2]=true; CLI_SELECTED[3]=true ;;
        esac
    done
}


# ============================================================================
# STEP COUNTER & GLOBALS
# ============================================================================
numberStep=0
step=0
export DOTFILE_PATH
DOTFILE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_VERSION="$(git -C "$DOTFILE_PATH" describe --tags --always --abbrev=7 2>/dev/null || echo "dev")"

# ============================================================================
# LOAD MODULES
# ============================================================================
_lib="${DOTFILE_PATH}/lib"
source "${_lib}/utils/colors.sh"
source "${_lib}/ui/setup.sh"
source "${_lib}/doctor.sh"
source "${_lib}/install/brew.sh"
source "${_lib}/install/git.sh"
source "${_lib}/install/zsh.sh"
source "${_lib}/install/asdf.sh"
source "${_lib}/update.sh"
source "${_lib}/ui/prompt_for_multiselect.sh"
source "${_lib}/install/core_setup.sh"

# ============================================================================
# MAIN
# ============================================================================
main() {
    set -uo pipefail  # -e omis intentionnellement : brew list / command -v retournent 1 légitimement
    parse_args "$@"

    # Initialize log file
    mkdir -p "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/install-$(date '+%Y-%m-%d_%H-%M-%S').log"

    clear
    print_banner
    check_prerequisites

    # Doctor mode — check health then exit
    if [[ "$DOCTOR_MODE" == true ]]; then
        run_doctor
        exit 0
    fi

    # Update non-Homebrew tools without showing the installer menu.
    if [[ "$UPDATE_MODE" == true ]]; then
        numberStep=1
        local update_status=0
        updateNonBrew || update_status=$?
        print_summary
        if [[ "$update_status" -eq 0 ]]; then
            log_success "Non-Homebrew update finished."
        else
            log_error "Some non-Homebrew updates failed; see the log for details."
        fi
        return "$update_status"
    fi

    run_core_setup
}

# Guard: only execute main when run directly (not when sourced for testing).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" == "core" ]]; then
        shift
        set -- --profile=core "$@"
    fi
    # Keep core setup usable before Node dependencies exist; app management uses Ink.
    if [[ ( $# -eq 0 || "$1" != -* ) && -d "${DOTFILE_PATH}/node_modules/ink" ]] && command -v node &>/dev/null; then
        exec node "${DOTFILE_PATH}/bin/dotfiles.mjs" "$@"
    elif [[ $# -gt 0 && "$1" != -* ]]; then
        echo "The Dotfiles CLI needs Node.js and its npm dependencies. Run: npm ci" >&2
        exit 1
    fi
    main "$@"
fi
