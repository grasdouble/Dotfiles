# Core prerequisite setup flow: selection, install progress, and summary.
# Requires lib/utils/colors.sh, lib/ui/setup.sh, lib/ui/prompt_for_multiselect.sh,
# and the component installers from this directory.
# Uses CLI_SELECTED, DRY_RUN, step, numberStep, LOG_FILE, and globals from main.sh.
has_cli_args() {
    for v in "${CLI_SELECTED[@]}"; do [[ "$v" == true ]] && return 0; done
    return 1
}
detect_installed() {
    local brew_ok="" git_ok="" zsh_ok="" asdf_ok=""
    command -v brew &>/dev/null && brew_ok=true
    command -v git  &>/dev/null && git_ok=true
    command -v zsh  &>/dev/null && [ -d "$HOME/.oh-my-zsh" ] && zsh_ok=true
    command -v asdf &>/dev/null && asdf_ok=true
    echo "${brew_ok};${git_ok};${zsh_ok};${asdf_ok}"
}

run_core_setup() {
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
