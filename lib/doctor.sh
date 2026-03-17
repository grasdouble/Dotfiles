#!/bin/bash

# ============================================================================
# DOCTOR MODE — environment health check
# ============================================================================
run_doctor() {
    echo -e "\n${BOLD}${CYAN}━━━ dotfiles doctor ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

    check_tool() {
        local label="$1"; local cmd="$2"
        if command -v "$cmd" &>/dev/null; then
            echo -e "  ${GREEN}✓${RESET}  $label $(command -v "$cmd" | head -1)"
        else
            echo -e "  ${RED}✗${RESET}  $label ${DIM}(not found)${RESET}"
        fi
    }

    check_dir() {
        local label="$1"; local path="$2"
        if [[ -e "$path" ]]; then
            echo -e "  ${GREEN}✓${RESET}  $label"
        else
            echo -e "  ${RED}✗${RESET}  $label ${DIM}($path missing)${RESET}"
        fi
    }

    check_symlink() {
        local label="$1"; local path="$2"; local target="$3"
        if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
            echo -e "  ${GREEN}✓${RESET}  $label → $target"
        elif [[ -e "$path" ]]; then
            echo -e "  ${YELLOW}~${RESET}  $label exists but not symlinked to $target"
        else
            echo -e "  ${RED}✗${RESET}  $label ${DIM}(missing)${RESET}"
        fi
    }

    echo -e "  ${BOLD}Core tools${RESET}"
    check_tool    "Homebrew"          "brew"
    check_tool    "Git"               "git"
    check_tool    "Zsh"               "zsh"
    check_tool    "ASDF"              "asdf"
    check_tool    "Node.js"           "node"
    check_tool    "pnpm"              "pnpm"
    check_tool    "Python"            "python3"
    check_symlink "~/.tool-versions"  "${HOME}/.tool-versions" "${DOTFILE_PATH}/config/asdf/tool-versions"

    echo ""
    echo -e "  ${BOLD}Shell config${RESET}"
    check_dir     "Oh My Zsh"                  "${HOME}/.oh-my-zsh"
    check_dir     "config/zsh/zsh_preload.zsh"  "${DOTFILE_PATH}/config/zsh/zsh_preload.zsh"
    check_dir     "config/zsh/zsh_postload.zsh" "${DOTFILE_PATH}/config/zsh/zsh_postload.zsh"
    check_symlink "~/.p10k.zsh"                 "${HOME}/.p10k.zsh" "${DOTFILE_PATH}/config/zsh/p10k.zsh"
    check_dir     "~/.zshrc"                    "${HOME}/.zshrc"

    if [[ -f "${HOME}/.zshrc" ]] && grep -q 'DOTFILE_PATH' "${HOME}/.zshrc"; then
        echo -e "  ${GREEN}✓${RESET}  ~/.zshrc has DOTFILE_PATH export"
    else
        echo -e "  ${RED}✗${RESET}  ~/.zshrc missing DOTFILE_PATH export"
    fi
    if [[ -f "${HOME}/.zshrc" ]] && grep -q 'zsh_preload\.zsh' "${HOME}/.zshrc"; then
        echo -e "  ${GREEN}✓${RESET}  ~/.zshrc has pre-omz dotfiles injection"
    else
        echo -e "  ${RED}✗${RESET}  ~/.zshrc missing pre-omz dotfiles injection"
    fi
    if [[ -f "${HOME}/.zshrc" ]] && grep -q 'zsh_postload\.zsh' "${HOME}/.zshrc"; then
        echo -e "  ${GREEN}✓${RESET}  ~/.zshrc has post-omz dotfiles injection"
    else
        echo -e "  ${RED}✗${RESET}  ~/.zshrc missing post-omz dotfiles injection"
    fi
    if [[ -f "${HOME}/.zsh_custom.zsh" ]]; then
        echo -e "  ${GREEN}✓${RESET}  ~/.zsh_custom.zsh exists"
    else
        echo -e "  ${YELLOW}!${RESET}  ~/.zsh_custom.zsh missing (run install to create)"
    fi

    check_dir "p10k theme"              "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
    check_dir "zsh-autosuggestions"     "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    check_dir "zsh-syntax-highlighting" "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

    echo ""
    echo -e "  ${BOLD}Logs${RESET}"
    local log_count
    log_count=$(find "$LOG_DIR" -maxdepth 1 -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${DIM}${log_count} install log(s) in ${LOG_DIR}${RESET}"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}
