# Zsh, Oh My Zsh, plugins, and shell configuration installation.
# Requires lib/utils/colors.sh and initialized install globals.

installZsh() {
    ((step += 1))
    log_step "Install ZSH + Oh My Zsh"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Install Zsh, Oh My Zsh, p10k, plugins, Nerd Font, symlinks + inject dotfiles into ~/.zshrc"
        track_result "Zsh" "ok"; return
    fi
    local install_omz=true

    local cache_file
    for cache_file in "$HOME"/.cache/p10k-instant-prompt-*; do
        [[ -e "$cache_file" ]] && rm -f "$cache_file"
    done
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_warning "An existing Oh My Zsh installation was found at ${HOME}/.oh-my-zsh."
        read -p "  Remove it and reinstall? This will delete any customizations inside ~/.oh-my-zsh. [y/N] " _omz_confirm
        if [[ "$_omz_confirm" =~ ^[Yy]$ ]]; then
            rm -Rf "${HOME}/.oh-my-zsh"
            log_info "Removed old Oh My Zsh"
        else
            install_omz=false
            log_info "Keeping existing Oh My Zsh installation."
        fi
    fi

    log_info "Installing Zsh..."
    if brew list zsh &>/dev/null; then brew reinstall zsh; else brew_install zsh; fi

    if [[ "$install_omz" == true ]]; then
        log_info "Installing Oh My Zsh..."
        local omz_installer
        omz_installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
            log_error "Failed to download the Oh My Zsh installer."
            track_result "Zsh" "error"
            return 1
        }
        if ! sh -c "$omz_installer" "" --unattended; then
            log_error "Oh My Zsh installation failed."
            track_result "Zsh" "error"
            return 1
        fi
    fi

    log_info "Linking p10k config..."
    [ -L "${HOME}/.p10k.zsh" ] && rm "${HOME}/.p10k.zsh"
    ln -s "${DOTFILE_PATH}/config/zsh/p10k.zsh" "${HOME}/.p10k.zsh"

    # Inject our config blocks into the OMZ-generated ~/.zshrc.
    # Block 1 — before `source $ZSH/oh-my-zsh.sh`:
    #   export DOTFILE_PATH + source preload (theme, plugins — must precede OMZ load)
    # Block 2 — at end of file:
    #   source postload (PATH, aliases, tools — after OMZ + third-party appends)
    # Idempotent: skip injection if already present.
    if ! grep -q 'zsh_preload\.zsh' "${HOME}/.zshrc"; then
        sed -i.bak \
            -e '/^source \$ZSH\/oh-my-zsh\.sh/i\
\
# ============================================================\
# dotfiles — pre-omz config\
# ============================================================\
export DOTFILE_PATH="'"${DOTFILE_PATH}"'"\
[[ -r "${DOTFILE_PATH}/config/zsh/zsh_preload.zsh" ]] \&\& source "${DOTFILE_PATH}/config/zsh/zsh_preload.zsh"\
# ============================================================' \
            "${HOME}/.zshrc"
        rm -f "${HOME}/.zshrc.bak"
        log_info "Injected pre-omz dotfiles block into ~/.zshrc"
    else
        log_info "pre-omz dotfiles block already present in ~/.zshrc — skipping"
    fi

    if ! grep -q 'zsh_postload\.zsh' "${HOME}/.zshrc"; then
        printf '\n# ============================================================\n# dotfiles — post-omz config\n# ============================================================\n[[ -r "${DOTFILE_PATH}/config/zsh/zsh_postload.zsh" ]] && source "${DOTFILE_PATH}/config/zsh/zsh_postload.zsh"\n# ============================================================\n' \
            >> "${HOME}/.zshrc"
        log_info "Appended post-omz dotfiles block to end of ~/.zshrc"
    else
        log_info "post-omz dotfiles block already present in ~/.zshrc — skipping"
    fi

    # Copy custom config template once — never overwritten on reinstall
    if [ ! -f "${HOME}/.zsh_custom.zsh" ]; then
        cp "${DOTFILE_PATH}/config/zsh/zsh_custom.zsh" "${HOME}/.zsh_custom.zsh"
        log_info "Created ~/.zsh_custom.zsh (personal overrides — edit freely)"
    else
        log_info "~/.zsh_custom.zsh already exists — skipping copy"
    fi

    log_info "Installing Zsh plugins..."
    local custom_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
    local -a plugin_repos=(
        "https://github.com/zsh-users/zsh-syntax-highlighting.git|${custom_dir}/plugins/zsh-syntax-highlighting"
        "https://github.com/zsh-users/zsh-autosuggestions|${custom_dir}/plugins/zsh-autosuggestions"
        "https://github.com/supercrabtree/k|${custom_dir}/plugins/k"
        "https://github.com/romkatv/powerlevel10k.git|${custom_dir}/themes/powerlevel10k"
    )
    local entry repo destination
    for entry in "${plugin_repos[@]}"; do
        repo="${entry%%|*}"
        destination="${entry#*|}"
        if [[ -d "$destination" ]]; then
            log_info "Already present — skipping ${destination}"
        elif [[ "$repo" == *powerlevel10k.git ]]; then
            if ! git clone --depth=1 "$repo" "$destination"; then
                log_error "Failed to clone ${repo}"
                track_result "Zsh" "error"
                return 1
            fi
        elif ! git clone "$repo" "$destination"; then
            log_error "Failed to clone ${repo}"
            track_result "Zsh" "error"
            return 1
        fi
    done
    [ "$(uname -s)" == "Darwin" ] && brew_install coreutils

    log_info "Installing Nerd Font..."
    ( cd "${HOME}/Library/Fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" \
        https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf )

    log_success "Zsh + Oh My Zsh + PowerLevel10k installed"
    track_result "Zsh" "ok"
}
