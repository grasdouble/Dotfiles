# Git installation and global identity setup.
# Requires lib/utils/colors.sh and initialized install globals.

installGit() {
    ((step += 1))
    log_step "Install Git"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install git && git config --global user.name/email"
        track_result "Git" "ok"; return
    fi
    brew_install git
    if command -v git &>/dev/null; then
        log_success "Git installed"
        track_result "Git" "ok"
    else
        log_error "Git installation failed"
        track_result "Git" "error"
        return
    fi
    echo ""
    local USERNAME=""
    while [[ -z "$USERNAME" ]]; do
        read -p "  Git username: " USERNAME
        [[ -z "$USERNAME" ]] && echo -e "  ${YELLOW}[WARN]${RESET}  Username cannot be empty."
    done
    git config --global user.name "$USERNAME"

    local EMAIL=""
    while [[ -z "$EMAIL" ]]; do
        read -p "  Git email:    " EMAIL
        [[ -z "$EMAIL" ]] && echo -e "  ${YELLOW}[WARN]${RESET}  Email cannot be empty."
    done
    git config --global user.email "$EMAIL"
    log_success "Git configured for $USERNAME <$EMAIL>"
}
