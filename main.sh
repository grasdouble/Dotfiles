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

has_cli_args() {
    for v in "${CLI_SELECTED[@]}"; do [[ "$v" == true ]] && return 0; done
    return 1
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
source "${_lib}/colors.sh"
source "${_lib}/ui.sh"
source "${_lib}/doctor.sh"
source "${_lib}/install_core.sh"
source "${_lib}/update.sh"
source "${_lib}/prompt_for_multiselect.sh"

# ============================================================================
# PRE-DETECT INSTALLED TOOLS
# ============================================================================
detect_installed() {
    local brew_ok="" git_ok="" zsh_ok="" asdf_ok=""
    command -v brew &>/dev/null && brew_ok=true
    command -v git  &>/dev/null && git_ok=true
    command -v zsh  &>/dev/null && [ -d "$HOME/.oh-my-zsh" ] && zsh_ok=true
    command -v asdf &>/dev/null && asdf_ok=true
    echo "${brew_ok};${git_ok};${zsh_ok};${asdf_ok}"
}

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

    # The bootstrap menu installs prerequisites only; app packages use Ink.
    local _c=$'\033'
    COLORS="${_c}[0;36m|${_c}[0;36m|${_c}[0;36m|${_c}[0;36m"
    HINTS="~1 min;~1 min;~5 min;~5 min"
    SECTIONS="0:Core Environment"
    INSTALLED_FLAGS=$(detect_installed)

    # Core items are checked by default unless already installed.
    IFS=';' read -ra _inst <<< "$INSTALLED_FLAGS"
    _defaults=()
    for i in {0..3}; do
        if [[ "${_inst[i]:-}" != "true" ]]; then
            _defaults+=("true")
        else
            _defaults+=("")
        fi
    done
    DEFAULTS=$(IFS=';'; echo "${_defaults[*]}")
    unset _inst _defaults

    log_info "This menu installs core prerequisites only. Use the Ink manager to install applications."
    # If CLI args provided, skip interactive menu
    if has_cli_args; then
        log_info "Running in CLI mode — skipping interactive menu"
        result=("${CLI_SELECTED[@]}")
    else
        prompt_for_multiselect result \
            "Brew;Git;Zsh + Oh My Zsh;ASDF (Node/Python/Java)" \
            "$DEFAULTS" \
            "$COLORS" \
            "$HINTS" \
            "$SECTIONS" \
            "$INSTALLED_FLAGS"
    fi

    for option in "${result[@]}"; do
        [[ $option == true ]] && ((numberStep++))
    done

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY-RUN: Would install ${numberStep} component(s). No changes made.\n"
    else
        log_info "Starting installation of ${numberStep} component(s)..."
        echo -e "  ${DIM}Logging to ${LOG_FILE}${RESET}\n"
    fi
    sleep 1

    for i in "${!result[@]}"; do
        if [[ ${result[$i]} == true ]]; then
            case $i in
                0)  installBrew ;;
                1)  installGit ;;
                2)  installZsh ;;
                3)  installAsdf ;;
            esac
        fi
    done

    print_summary
    print_post_install
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
