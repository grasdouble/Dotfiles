# Homebrew installation.
# Requires lib/utils/colors.sh and initialized install globals.

installBrew() {
    ((step += 1))
    log_step "Install Brew"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "/bin/bash Homebrew install script"
        track_result "Brew" "ok"; return
    fi
    if ! command -v brew &>/dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if command -v brew &>/dev/null; then
            log_success "Homebrew installed successfully"
            track_result "Brew" "ok"
        else
            log_error "Homebrew installation failed"
            track_result "Brew" "error"
        fi
    else
        log_skip "Homebrew"
        track_result "Brew" "skip"
    fi
}
