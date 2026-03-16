#!/bin/bash

# ============================================================================
# WELCOME BANNER
# ============================================================================
print_banner() {
    echo -e "${CYAN}"
    echo "  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
    echo "  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
    echo "  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
    echo "  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
    echo "  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
    echo "  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
    echo -e "${RESET}"
    echo -e "  ${BOLD}macOS Developer Environment Setup${RESET}  ${DIM}v${DOTFILES_VERSION} — by Noofreuuuh${RESET}"
    echo -e "  ${DIM}https://github.com/noofreuuuh/Dotfiles${RESET}"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "\n  ${YELLOW}${BOLD}DRY-RUN MODE — nothing will be installed${RESET}"
    fi
    echo ""
    echo -e "  ${DIM}Use ↑↓ to navigate, SPACE to toggle, ENTER to confirm, a/n to (de)select all${RESET}"
    echo ""
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================
check_prerequisites() {
    echo -e "${BOLD}Checking prerequisites...${RESET}\n"
    local has_error=false

    if [[ "$(uname)" == "Darwin" ]]; then
        local macos_version
        macos_version=$(sw_vers -productVersion)
        log_success "macOS $macos_version detected"
    else
        log_warning "This script is designed for macOS. Some features may not work on $(uname)."
    fi

    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        log_success "Apple Silicon (ARM64) detected"
    elif [[ "$arch" == "x86_64" ]]; then
        log_warning "Intel (x86_64) detected — Homebrew will install to /usr/local"
    else
        log_warning "Unknown architecture: $arch"
    fi

    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools installed"
    else
        log_warning "Xcode Command Line Tools not found — installing..."
        xcode-select --install 2>/dev/null
        echo -e "  ${YELLOW}→ Please complete the Xcode CLT popup, then re-run this script.${RESET}"
        has_error=true
    fi

    if curl -s --max-time 3 https://brew.sh &>/dev/null; then
        log_success "Internet connection available"
    else
        log_error "No internet connection detected — installation will likely fail."
        has_error=true
    fi

    echo -e "  ${DIM}Log file: ${LOG_FILE}${RESET}\n"

    if [[ "$has_error" == true ]]; then
        echo -e "${YELLOW}Some prerequisites are missing. Proceeding anyway — errors may occur.${RESET}\n"
        sleep 2
    else
        log_success "All prerequisites met."
        sleep 1
    fi
    echo ""
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  Installation Summary${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    local ok_count=0 skip_count=0 error_count=0
    for entry in "${INSTALL_RESULTS[@]}"; do
        local status="${entry%%|*}"
        local name="${entry##*|}"
        case "$status" in
            ok)    echo -e "  ${GREEN}✓${RESET}  $name"; ((ok_count++)) ;;
            skip)  echo -e "  ${DIM}–${RESET}  $name ${DIM}(skipped)${RESET}"; ((skip_count++)) ;;
            error) echo -e "  ${RED}✗${RESET}  $name ${RED}(failed)${RESET}"; ((error_count++)) ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}${ok_count} installed${RESET}  ${DIM}${skip_count} skipped${RESET}  ${RED}${error_count} failed${RESET}"
    echo -e "  ${DIM}Full log: ${LOG_FILE}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ============================================================================
# POST-INSTALL NEXT STEPS
# ============================================================================
print_post_install() {
    echo ""
    echo -e "${BOLD}  Next steps${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${GREEN}1.${RESET} Reload your shell:"
    echo -e "     ${BOLD}source ~/.zshrc${RESET}  or open a new terminal"
    echo ""
    echo -e "  ${YELLOW}Manual steps required:${RESET}"
    echo -e "  ${DIM}□${RESET}  iTerm2: Set font to ${BOLD}DroidSansMono Nerd Font${RESET} (Preferences → Profiles → Text)"
    echo -e "  ${DIM}□${RESET}  Run ${BOLD}p10k configure${RESET} to customize your prompt"
    echo -e "  ${DIM}□${RESET}  Sign in to apps: Slack, WhatsApp, Discord, Notion, Spotify..."
    echo -e "  ${DIM}□${RESET}  Docker/Colima: run ${BOLD}dockerStart${RESET} alias to start the daemon"
    echo -e "  ${DIM}□${RESET}  Add personal aliases/config to ${BOLD}~/.zshrc${RESET} (below the source line)"
    if [[ " ${INSTALL_RESULTS[*]} " == *"Games"* ]]; then
        echo -e "  ${DIM}□${RESET}  Sony PS Remote Play: move app manually to /Applications/Games"
    fi
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}${BOLD}Setup complete. Happy coding!${RESET}"
    echo ""

    # macOS notification
    if [[ "$(uname)" == "Darwin" && "$DRY_RUN" == false ]]; then
        osascript -e 'display notification "All done! Check your terminal for next steps." with title "Dotfiles Setup Complete"' 2>/dev/null || true
    fi
}
