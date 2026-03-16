#!/bin/bash

# ============================================================================
# CORE INSTALL FUNCTIONS
# Requires: lib/colors.sh (log_*, track_result, brew_install, DRY_RUN)
#           DOTFILE_PATH, step, numberStep, LOG_FILE
# ============================================================================

installBrew() {
    ((step++))
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

installGit() {
    ((step++))
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

installZsh() {
    ((step++))
    log_step "Install ZSH + Oh My Zsh"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Install Zsh, Oh My Zsh, p10k, plugins, Nerd Font, symlinks + inject dotfiles into ~/.zshrc"
        track_result "Zsh" "ok"; return
    fi

    log_info "Cleaning previous Zsh setup..."
    rm -f "$HOME/.cache/p10k-instant-prompt-*"
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_warning "An existing Oh My Zsh installation was found at ${HOME}/.oh-my-zsh."
        read -p "  Remove it and reinstall? This will delete any customizations inside ~/.oh-my-zsh. [y/N] " _omz_confirm
        if [[ "$_omz_confirm" =~ ^[Yy]$ ]]; then
            rm -Rf "${HOME}/.oh-my-zsh"
            log_info "Removed old Oh My Zsh"
        else
            log_warning "Skipping Oh My Zsh removal — install may fail if the existing setup is incompatible."
        fi
    fi

    log_info "Installing Zsh..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if brew list zsh &>/dev/null; then brew reinstall zsh; else brew_install zsh; fi
    elif [[ "$(uname -s)" == "Linux" ]]; then
        sudo apt-get install -y zsh
    fi

    echo "export DOTFILE_PATH=\"${DOTFILE_PATH}\"" > "${HOME}/.dotfiles-config-path.zsh"

    log_info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    log_info "Linking Zsh config..."
    # Symlink versioned configs — never modified by third-party tools
    [ -L "${HOME}/.zsh_preload.zsh" ] && rm "${HOME}/.zsh_preload.zsh"
    ln -s "${DOTFILE_PATH}/config/zsh/zsh_preload.zsh" "${HOME}/.zsh_preload.zsh"
    [ -L "${HOME}/.zsh_postload.zsh" ] && rm "${HOME}/.zsh_postload.zsh"
    ln -s "${DOTFILE_PATH}/config/zsh/zsh_postload.zsh" "${HOME}/.zsh_postload.zsh"

    # Inject our config blocks into the OMZ-generated ~/.zshrc.
    # Before `source $ZSH/oh-my-zsh.sh`: source ~/.zsh_preload.zsh (theme, plugins, p10k — must precede OMZ load)
    # At end of file:                    source ~/.zsh_postload.zsh (PATH, aliases, tools — after OMZ + third-party appends)
    # Idempotent: skip injection if already present.
    if ! grep -q 'zsh_preload\.zsh' "${HOME}/.zshrc"; then
        sed -i.bak \
            -e '/^source \$ZSH\/oh-my-zsh\.sh/i\
\
# ============================================================\
# dotfiles — pre-omz config\
# ============================================================\
[[ -r "${HOME}/.zsh_preload.zsh" ]] \&\& source "${HOME}/.zsh_preload.zsh"\
# ============================================================' \
            "${HOME}/.zshrc"
        rm -f "${HOME}/.zshrc.bak"
        log_info "Injected pre-omz dotfiles block into ~/.zshrc"
    else
        log_info "pre-omz dotfiles block already present in ~/.zshrc — skipping"
    fi

    if ! grep -q 'zsh_postload\.zsh' "${HOME}/.zshrc"; then
        printf '\n# ============================================================\n# dotfiles — post-omz config\n# ============================================================\n[[ -r "${HOME}/.zsh_postload.zsh" ]] && source "${HOME}/.zsh_postload.zsh"\n# ============================================================\n' \
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

    [ -f "${HOME}/.zlogin" ] && rm "${HOME}/.zlogin"
    ln -s "${DOTFILE_PATH}/config/zsh/zlogin" "${HOME}/.zlogin"

    log_info "Installing Zsh plugins..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    [ "$(uname -s)" == "Darwin" ] && brew_install coreutils
    git clone https://github.com/supercrabtree/k "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k"

    log_info "Installing PowerLevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    log_info "Installing Nerd Font..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ( cd "${HOME}/Library/Fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" \
            https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf )
    elif [[ "$(uname -s)" == "Linux" ]]; then
        [ ! -d "${HOME}/.local/share/fonts" ] && mkdir -p "${HOME}/.local/share/fonts"
        ( cd "${HOME}/.local/share/fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" \
            https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf )
    fi

    log_success "Zsh + Oh My Zsh + PowerLevel10k installed"
    track_result "Zsh" "ok"
}

installAsdf() {
    ((step++))
    log_step "Install ASDF"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install asdf + plugins: nodejs, pnpm, python, java"
        track_result "ASDF" "ok"; return
    fi
    if brew list asdf &>/dev/null; then brew reinstall asdf; else brew_install asdf; fi

    log_info "Linking ~/.tool-versions..."
    [ -L "${HOME}/.tool-versions" ] && rm "${HOME}/.tool-versions"
    ln -s "${DOTFILE_PATH}/config/asdf/tool-versions" "${HOME}/.tool-versions"

    log_info "Adding ASDF plugins (Node, pnpm, Python, Java)..."

    _asdf_plugin_add() {
        local plugin="$1"; shift
        if zsh -c "asdf plugin list" 2>/dev/null | grep -q "^${plugin}$"; then
            log_skip "asdf plugin ${plugin}"
        else
            log_info "Adding ${plugin} plugin..."
            if ! zsh -c "asdf plugin add ${plugin} $*" 2>&1 | tee -a "$LOG_FILE"; then
                log_warning "asdf plugin add ${plugin} failed — continuing"
            fi
        fi
    }

    _asdf_install() {
        local plugin="$1"; local version="$2"
        log_info "Installing ${plugin} ${version}..."
        if ! zsh -c "asdf install ${plugin} ${version}" 2>&1 | tee -a "$LOG_FILE"; then
            log_warning "asdf install ${plugin} ${version} failed — continuing"
        fi
    }

    _asdf_plugin_add nodejs "https://github.com/asdf-vm/asdf-nodejs.git"
    _asdf_install nodejs latest

    _asdf_plugin_add pnpm "https://github.com/jonathanmorley/asdf-pnpm.git"
    _asdf_install pnpm latest

    _asdf_plugin_add python
    # Note: no specific version installed for python; set per-project via .tool-versions

    _asdf_plugin_add java "https://github.com/halcyon/asdf-java.git"
    _asdf_install java adoptopenjdk-11.0.27+6

    # Update config/asdf/tool-versions with the actually installed versions.
    # Uses `asdf list <plugin> | sort -V | tail -1` — reliable regardless of `asdf current` bugs.
    log_info "Updating config/asdf/tool-versions with installed versions..."
    _update_tool_versions() {
        local plugin="$1"
        local version
        version=$(zsh -c "asdf list ${plugin} 2>/dev/null | tr -d ' *' | sort -V | tail -1")
        if [[ -n "$version" ]]; then
            if grep -q "^${plugin} " "${DOTFILE_PATH}/config/asdf/tool-versions"; then
                sed -i.bak "s|^${plugin} .*|${plugin} ${version}|" "${DOTFILE_PATH}/config/asdf/tool-versions"
                rm -f "${DOTFILE_PATH}/config/asdf/tool-versions.bak"
            else
                echo "${plugin} ${version}" >> "${DOTFILE_PATH}/config/asdf/tool-versions"
            fi
            log_info "  ${plugin} → ${version}"
        else
            log_warning "  could not resolve installed version for ${plugin} — skipping"
        fi
    }
    _update_tool_versions nodejs
    _update_tool_versions pnpm

    log_success "ASDF and plugins installed"
    track_result "ASDF" "ok"
}
