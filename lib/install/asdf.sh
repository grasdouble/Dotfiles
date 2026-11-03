# ASDF installation, plugins, and runtime setup.
# Requires lib/utils/colors.sh and initialized install globals.

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

    # Only needed during `asdf install nodejs` — not a persistent shell variable
    export ASDF_NPM_DEFAULT_PACKAGES_FILE="${DOTFILE_PATH}/config/asdf/default-npm-packages"

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
