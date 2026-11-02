#!/bin/bash

# Update third-party tools and checkouts installed outside Homebrew.
# Requires colors.sh, DOTFILE_PATH, DRY_RUN, and INSTALL_RESULTS.
updateNonBrew() {
    ((step++))
    log_step "Update non-Homebrew tools"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Update Oh My Zsh and Git plugins, ASDF plugins/runtimes, npm globals, Neovim plugins/LSPs/formatters, Treesitter parsers, and Nerd Font"
        track_result "Non-Homebrew updates" "ok"
        return
    fi
    local errors=0 path latest plugin version tool_versions
    local -a checkouts=(
        "${HOME}/.oh-my-zsh"
        "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
        "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
        "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k"
        "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"
    )

    for path in "${checkouts[@]}"; do
        if [[ ! -e "$path/.git" ]]; then
            log_info "Not installed as a Git checkout — skipping ${path}"
        elif ! git -C "$path" diff --quiet || ! git -C "$path" diff --cached --quiet; then
            log_error "Local changes detected in ${path}; refusing to update it."
            errors=1
        elif git -C "$path" pull --ff-only; then
            log_success "Updated ${path}"
        else
            log_error "Could not update ${path}; branch divergence may need attention."
            errors=1
        fi
    done

    if command -v asdf >/dev/null 2>&1; then
        if ! asdf plugin update --all; then
            log_error "Could not update ASDF plugins."
            errors=1
        fi

        tool_versions="${DOTFILE_PATH}/config/asdf/tool-versions"
        for plugin in nodejs pnpm; do
            latest=$(asdf latest "$plugin") || latest=""
            if [[ -z "$latest" ]]; then
                log_error "Could not resolve latest ${plugin} version."
                errors=1
                continue
            fi
            if ! asdf install "$plugin" "$latest"; then
                log_error "Could not install ${plugin} ${latest}."
                errors=1
                continue
            fi
            if grep -q "^${plugin} " "$tool_versions"; then
                if ! sed -i.bak "s|^${plugin} .*|${plugin} ${latest}|" "$tool_versions"; then
                    log_error "Could not update ${plugin} in ${tool_versions}."
                    errors=1
                    continue
                fi
                rm -f "${tool_versions}.bak"
            elif ! printf '%s %s\n' "$plugin" "$latest" >> "$tool_versions"; then
                log_error "Could not add ${plugin} to ${tool_versions}."
                errors=1
                continue
            fi
            log_success "Updated ${plugin} to ${latest} in ${tool_versions}"
        done

        if grep -q '^java ' "$tool_versions"; then
            version=$(awk '$1 == "java" { print $2; exit }' "$tool_versions")
            if ! asdf install java "$version"; then
                log_error "Could not ensure pinned Java version ${version}."
                errors=1
            fi
        fi
    else
        log_info "ASDF is not installed — skipping ASDF updates."
    fi

    if command -v nvim >/dev/null 2>&1; then
        if ! nvim --headless '+Lazy! sync' '+MasonToolsUpdateSync' '+qa'; then
            log_error "Neovim plugin, language server, or formatter update failed."
            errors=1
        fi
    else
        log_info "Neovim is not installed — skipping Neovim updates."
    fi

    local font_dir font_path font_url

    local npm_package
    if command -v npm >/dev/null 2>&1; then
        while IFS= read -r npm_package || [[ -n "$npm_package" ]]; do
            [[ -z "$npm_package" || "$npm_package" == \#* ]] && continue
            if npm install --global "${npm_package}@latest"; then
                log_success "Updated global npm package ${npm_package}"
            else
                log_error "Could not update global npm package ${npm_package}."
                errors=1
            fi
        done < "${DOTFILE_PATH}/config/asdf/default-npm-packages"
    else
        log_info "npm is not installed — skipping global npm package updates."
    fi
    if [[ "$(uname -s)" == "Darwin" ]]; then
        font_dir="${HOME}/Library/Fonts"
    else
        font_dir="${HOME}/.local/share/fonts"
    fi
    font_path="${font_dir}/Droid Sans Mono for Powerline Nerd Font Complete.otf"
    font_url="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf"
    if mkdir -p "$font_dir" && curl -fsSLo "${font_path}.tmp" "$font_url" && mv "${font_path}.tmp" "$font_path"; then
        log_success "Updated Nerd Font"
    else
        rm -f "${font_path}.tmp"
        log_error "Could not update Nerd Font."
        errors=1
    fi

    if [[ "$errors" -eq 0 ]]; then
        log_success "Non-Homebrew updates completed"
        track_result "Non-Homebrew updates" "ok"
    else
        track_result "Non-Homebrew updates" "error"
        return 1
    fi
}
