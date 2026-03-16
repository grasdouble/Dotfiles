#!/bin/bash

# ============================================================================
# CLI ARGUMENTS
# Usage: bash main.sh [options]
#   --brew --git --zsh --asdf --dev --tools --comm --office --games --others --llm --pro
#   --profile=core | --profile=pro | --profile=gaming | --profile=dev
#   --dry-run       Simulate installation without executing anything
#   --doctor        Check environment health and exit
# ============================================================================
DRY_RUN=false
DOCTOR_MODE=false
declare -a CLI_SELECTED=("" "" "" "" "" "" "" "" "" "" "" "")  # 12 slots

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run)    DRY_RUN=true ;;
            --doctor)     DOCTOR_MODE=true ;;
            --brew)       CLI_SELECTED[0]=true ;;
            --git)        CLI_SELECTED[1]=true ;;
            --zsh)        CLI_SELECTED[2]=true ;;
            --asdf)       CLI_SELECTED[3]=true ;;
            --dev)        CLI_SELECTED[4]=true ;;
            --tools)      CLI_SELECTED[5]=true ;;
            --comm)       CLI_SELECTED[6]=true ;;
            --office)     CLI_SELECTED[7]=true ;;
            --games)      CLI_SELECTED[8]=true ;;
            --others)     CLI_SELECTED[9]=true ;;
            --llm)        CLI_SELECTED[10]=true ;;
            --pro)        CLI_SELECTED[11]=true ;;
            --profile=core)
                CLI_SELECTED[0]=true; CLI_SELECTED[1]=true
                CLI_SELECTED[2]=true; CLI_SELECTED[3]=true ;;
            --profile=dev)
                CLI_SELECTED[0]=true; CLI_SELECTED[1]=true
                CLI_SELECTED[2]=true; CLI_SELECTED[3]=true; CLI_SELECTED[4]=true ;;
            --profile=pro)
                CLI_SELECTED[11]=true ;;
            --profile=gaming)
                CLI_SELECTED[0]=true; CLI_SELECTED[8]=true ;;
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
source "${_lib}/install_software.sh"
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

    local dev_ok="" tools_ok="" comm_ok="" office_ok=""
    local games_ok="" others_ok="" llm_ok="" pro_ok=""
    [ -d "/Applications/Developments/Visual Studio Code.app" ] && dev_ok=true
    [ -d "/Applications/Tools/Rectangle.app" ]                  && tools_ok=true
    [ -d "/Applications/Communications/Slack.app" ]             && comm_ok=true
    [ -d "/Applications/Office/Microsoft Word.app" ]            && office_ok=true
    [ -d "/Applications/Games/Steam.app" ]                      && games_ok=true
    [ -d "/Applications/Others/Spotify.app" ]                   && others_ok=true
    [ -d "/Applications/Developments/LM Studio.app" ]           && llm_ok=true
    # Pro bundle: representative subset
    [ -d "/Applications/Developments/Sublime Text.app" ] && \
    [ -d "/Applications/Tools/Rectangle.app" ] && \
    [ -d "/Applications/Communications/Discord.app" ] && \
    [ -d "/Applications/Developments/Visual Studio Code.app" ] && pro_ok=true

    echo "${brew_ok};${git_ok};${zsh_ok};${asdf_ok};${dev_ok};${tools_ok};${comm_ok};${office_ok};${games_ok};${others_ok};${llm_ok};${pro_ok}"
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

    # Colors per option (Core=cyan, Software=yellow, Presets=magenta)
    local _c=$'\033'
    COLORS="${_c}[0;36m|${_c}[0;36m|${_c}[0;36m|${_c}[0;36m|${_c}[1;33m|${_c}[1;33m|${_c}[1;33m|${_c}[1;33m|${_c}[1;33m|${_c}[1;33m|${_c}[0;35m|${_c}[0;35m"
    HINTS="~1 min;~1 min;~5 min;~5 min;~10 min;~5 min;~3 min;~15 min;~10 min;~5 min;~8 min;~10 min"
    SECTIONS="0:Core Environment;4:Software;11:Presets"
    INSTALLED_FLAGS=$(detect_installed)

    # Build defaults: Core items (0-3) checked by default unless already installed.
    # Software/Preset items (4-11) never checked by default.
    IFS=';' read -ra _inst <<< "$INSTALLED_FLAGS"
    _defaults=()
    for i in {0..11}; do
        if [[ i -lt 4 && "${_inst[i]:-}" != "true" ]]; then
            _defaults+=("true")   # Core, not yet installed → check by default
        else
            _defaults+=("")       # already installed, or Software/Preset → unchecked
        fi
    done
    DEFAULTS=$(IFS=';'; echo "${_defaults[*]}")
    unset _inst _defaults

    # If CLI args provided, skip interactive menu
    if has_cli_args; then
        log_info "Running in CLI mode — skipping interactive menu"
        result=("${CLI_SELECTED[@]}")
    else
        prompt_for_multiselect result \
            "Brew;Git;Zsh + Oh My Zsh;ASDF (Node/Python/Java);Development;Tools;Communication;Office;Games;Others;LLM Tools;Pro Bundle" \
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
                4)  installSoftwareDevelopment ;;
                5)  installSoftwareTools ;;
                6)  installSoftwareCommunication ;;
                7)  installSoftwareOffice ;;
                8)  installSoftwareGames ;;
                9)  installSoftwareOthers ;;
                10) installSoftwareLLM ;;
                11) installSoftwarePro ;;
            esac
        fi
    done

    print_summary
    print_post_install
}

# Guard: only execute main when run directly (not when sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
