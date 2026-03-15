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

source ./prompt_for_multiselect.sh

# ============================================================================
# COLORS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ============================================================================
# LOGGING HELPERS
# ============================================================================
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARN]${RESET}  $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1" | tee -a "$LOG_FILE"; }
log_skip()    { echo -e "${DIM}[SKIP]${RESET}  $1 (already installed)" | tee -a "$LOG_FILE"; }
log_step()    {
    echo -e "\n${BOLD}${CYAN}━━━ [${step}/${numberStep}] $1 ${RESET}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
    print_progress
}
log_dry()     { echo -e "${YELLOW}[DRY-RUN]${RESET} Would run: $1"; }

# ============================================================================
# LOG FILE SETUP  (initialized in main; defined here so helpers can reference)
# ============================================================================
LOG_DIR="${HOME}/.dotfiles-logs"
LOG_FILE="/dev/null"  # overridden in main() before any logging

# ============================================================================
# PROGRESS BAR
# ============================================================================
print_progress() {
    [[ $numberStep -eq 0 ]] && return
    local filled=$(( step * 30 / numberStep ))
    local empty=$(( 30 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++));  do bar+="░"; done
    echo -e "  ${CYAN}[${bar}]${RESET} ${BOLD}${step}/${numberStep}${RESET}"
}

# ============================================================================
# INSTALL RESULT TRACKING
# ============================================================================
declare -a INSTALL_RESULTS=()

track_result() {
    local name="$1"
    local status="$2"  # "ok" | "skip" | "error"
    INSTALL_RESULTS+=("${status}|${name}")
}

# ============================================================================
# BREW WRAPPER (dry-run aware)
# ============================================================================
brew_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install $*"
    else
        brew install "$@"
    fi
}

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
    echo -e "  ${BOLD}macOS Developer Environment Setup${RESET}  ${DIM}v3.0.0 — by Noofreuuuh${RESET}"
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
# DOCTOR MODE
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
    check_tool "Homebrew" "brew"
    check_tool "Git" "git"
    check_tool "Zsh" "zsh"
    check_tool "ASDF" "asdf"
    check_tool "Node.js" "node"
    check_tool "pnpm" "pnpm"
    check_tool "Python" "python3"

    echo ""
    echo -e "  ${BOLD}Shell config${RESET}"
    check_dir    "Oh My Zsh"         "${HOME}/.oh-my-zsh"
    check_symlink "~/.zshrc"         "${HOME}/.zshrc"  "${DOTFILE_PATH}/zsh/zshrc"
    check_symlink "~/.zlogin"        "${HOME}/.zlogin" "${DOTFILE_PATH}/zsh/zlogin"
    check_dir    "~/.custom.zsh"     "${HOME}/.custom.zsh"
    check_dir    "p10k theme"        "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
    check_dir    "zsh-autosuggestions" "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    check_dir    "zsh-syntax-highlighting" "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

    echo ""
    echo -e "  ${BOLD}Logs${RESET}"
    local log_count
    log_count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${DIM}${log_count} install log(s) in ${LOG_DIR}${RESET}"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# ============================================================================
# STEP COUNTER (initialized in main; defined here so install functions can reference)
# ============================================================================
numberStep=0
step=0
export DOTFILE_PATH=${PWD}

# ============================================================================
# INSTALL FUNCTIONS
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
    read -p "  Git username: " USERNAME
    git config --global user.name "$USERNAME"
    read -p "  Git email:    " EMAIL
    git config --global user.email "$EMAIL"
    log_success "Git configured for $USERNAME <$EMAIL>"
}

installZsh() {
    ((step++))
    log_step "Install ZSH + Oh My Zsh"
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Install Zsh, Oh My Zsh, p10k, plugins, Nerd Font, symlinks"
        track_result "Zsh" "ok"; return
    fi

    log_info "Cleaning previous Zsh setup..."
    rm -f "$HOME/.cache/p10k-instant-prompt-*"
    [ -d "${HOME}/.oh-my-zsh" ] && rm -Rf "${HOME}/.oh-my-zsh" && log_info "Removed old Oh My Zsh"

    log_info "Installing Zsh..."
    if [ "$(uname)" == "Darwin" ]; then
        if brew list zsh &>/dev/null; then brew reinstall zsh; else brew_install zsh; fi
    elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
        sudo apt-get install -y zsh
    fi

    echo "export DOTFILE_PATH=\"${PWD}\"" > "${HOME}/.dotfiles-config-path.zsh"
    [ ! -f "${HOME}/.custom.zsh" ] && cp "${PWD}/zsh/custom.zsh" "${HOME}/.custom.zsh" && log_info "Created ~/.custom.zsh"

    log_info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    log_info "Linking Zsh config..."
    [ -f "${HOME}/.zshrc" ] && rm "${HOME}/.zshrc"
    ln -s "${PWD}/zsh/zshrc" "${HOME}/.zshrc"
    [ -f "${HOME}/.zlogin" ] && rm "${HOME}/.zlogin"
    ln -s "${PWD}/zsh/zlogin" "${HOME}/.zlogin"

    log_info "Installing Zsh plugins..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    [ "$(uname)" == "Darwin" ] && brew_install coreutils
    git clone https://github.com/supercrabtree/k "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k"

    log_info "Installing PowerLevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    log_info "Installing Nerd Font..."
    if [ "$(uname)" == "Darwin" ]; then
        cd "${HOME}/Library/Fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" \
            https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf
    elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
        [ ! -d "${HOME}/.local/share/fonts" ] && mkdir -p "${HOME}/.local/share/fonts"
        cd "${HOME}/.local/share/fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" \
            https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf
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

    ((step++))
    log_step "Add ASDF plugins (Node, pnpm, Python, Java)"
    log_info "Adding Node.js plugin..."
    zsh -c "asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git"
    zsh -c "asdf install nodejs latest"

    log_info "Adding pnpm plugin..."
    zsh -c "asdf plugin add pnpm https://github.com/jonathanmorley/asdf-pnpm.git"
    zsh -c "asdf install pnpm latest"

    log_info "Adding Python plugin..."
    zsh -c "asdf plugin add python"

    log_info "Adding Java plugin (adoptopenjdk-11)..."
    zsh -c "asdf plugin add java https://github.com/halcyon/asdf-java.git"
    zsh -c "asdf install java adoptopenjdk-11.0.27+6"

    log_success "ASDF and plugins installed"
    track_result "ASDF" "ok"
}

installSoftwarePro() {
    ((step++))
    log_step "Install Software: Pro Bundle"
    brew_install --cask visual-studio-code --appdir=/Applications/Developments
    brew_install --cask iterm2 --appdir=/Applications/Developments
    brew_install --cask sublime-text --appdir=/Applications/Developments
    brew_install qemu colima docker
    brew_install --cask rectangle --appdir=/Applications/Tools
    brew_install --cask cakebrew --appdir=/Applications/Tools
    brew_install --cask grandperspective --appdir=/Applications/Tools
    brew_install --cask spotify --appdir=/Applications/Others
    brew_install --cask vivaldi --appdir=/Applications/Others
    brew_install --cask audio-hijack --appdir=/Applications/Communications
    brew_install --cask whatsapp --appdir=/Applications/Communications
    brew_install --cask discord --appdir=/Applications/Communications
    log_success "Software: Pro Bundle installed"
    track_result "Software: Pro" "ok"
}

installSoftwareDevelopment() {
    ((step++))
    log_step "Install Software: Development"
    brew_install --cask visual-studio-code --appdir=/Applications/Developments
    brew_install --cask iterm2 --appdir=/Applications/Developments
    brew_install --cask wave --appdir=/Applications/Developments
    brew_install --cask sublime-text --appdir=/Applications/Developments
    brew_install --cask notion --appdir=/Applications/Developments
    brew_install --cask anki --appdir=/Applications/Developments
    brew_install qemu colima docker
    log_success "Software: Development installed"
    track_result "Software: Development" "ok"
}

installSoftwareLLM() {
    ((step++))
    log_step "Install Software: LLM Tools"
    brew_install --cask lm-studio --appdir=/Applications/Developments
    brew_install --cask chatgpt --appdir=/Applications/Developments
    brew_install --cask superwhisper --appdir=/Applications/Developments
    brew_install opencode
    brew_install --cask opencode-desktop --appdir=/Applications/Developments
    brew_install --cask antigravity --appdir=/Applications/Developments
    log_success "Software: LLM Tools installed"
    track_result "Software: LLM" "ok"
}

installSoftwareTools() {
    ((step++))
    log_step "Install Software: Tools"
    brew_install --cask rectangle --appdir=/Applications/Tools
    brew_install --cask oversight --appdir=/Applications/Tools
    brew_install --cask logi-options-plus --appdir=/Applications/Tools
    brew_install --cask jdownloader --appdir=/Applications/Tools
    brew_install --cask background-music --appdir=/Applications/Tools
    brew_install --cask grandperspective --appdir=/Applications/Tools
    brew_install --cask pearcleaner --appdir=/Applications/Tools
    brew_install --cask clop --appdir=/Applications/Tools
    brew_install --cask protonvpn --appdir=/Applications/Tools
    brew_install --cask jordanbaird-ice --appdir=/Applications/Tools
    log_success "Software: Tools installed"
    track_result "Software: Tools" "ok"
}

installSoftwareCommunication() {
    ((step++))
    log_step "Install Software: Communication"
    brew_install --cask audio-hijack --appdir=/Applications/Communications
    brew_install --cask slack --appdir=/Applications/Communications
    brew_install --cask whatsapp --appdir=/Applications/Communications
    brew_install --cask discord --appdir=/Applications/Communications
    brew_install --cask signal --appdir=/Applications/Communications
    log_success "Software: Communication installed"
    track_result "Software: Communication" "ok"
}

installSoftwareOffice() {
    ((step++))
    log_step "Install Software: Office"
    brew_install --cask microsoft-office --appdir=/Applications/Office
    log_success "Software: Office installed"
    track_result "Software: Office" "ok"
}

installSoftwareGames() {
    ((step++))
    log_step "Install Software: Games"
    brew_install --cask --no-quarantine nvidia-geforce-now --appdir=/Applications/Games
    brew_install --cask --no-quarantine epic-games --appdir=/Applications/Games
    brew_install --cask --no-quarantine steam --appdir=/Applications/Games
    brew_install --cask --no-quarantine prismlauncher --appdir=/Applications/Games
    brew_install --cask --no-quarantine scummvm --appdir=/Applications/Games
    brew_install --cask obs --appdir=/Applications/Games
    brew_install --cask --no-quarantine openemu --appdir=/Applications/Games
    brew_install --cask sony-ps-remote-play --appdir=/Applications/Games
    brew_install --cask moonlight --appdir=/Applications/Games
    log_success "Software: Games installed"
    track_result "Software: Games" "ok"
}

installSoftwareOthers() {
    ((step++))
    log_step "Install Software: Others"
    brew_install --cask --no-quarantine spotify --appdir=/Applications/Others
    brew_install --cask calibre --appdir=/Applications/Others
    brew_install --cask kindle-previewer --appdir=/Applications/Others
    brew_install --cask send-to-kindle --appdir=/Applications/Others
    brew_install --cask hakuneko --appdir=/Applications/Others
    brew_install --cask affinity --appdir=/Applications/Others
    brew_install --cask --no-quarantine vivaldi --appdir=/Applications/Others
    log_success "Software: Others installed"
    track_result "Software: Others" "ok"
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
    echo -e "  ${DIM}□${RESET}  Add personal aliases/config to ${BOLD}~/.custom.zsh${RESET}"
    echo -e "  ${DIM}□${RESET}  Sony PS Remote Play: move app manually to /Applications/Games"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${GREEN}${BOLD}Setup complete. Happy coding!${RESET}"
    echo ""

    # macOS notification
    if [[ "$(uname)" == "Darwin" && "$DRY_RUN" == false ]]; then
        osascript -e 'display notification "All done! Check your terminal for next steps." with title "Dotfiles Setup Complete"' 2>/dev/null || true
    fi
}

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
    [ -d "/Applications/Developments/Sublime Text.app" ] && [ -d "/Applications/Tools/Rectangle.app" ] && pro_ok=true

    echo "${brew_ok};${git_ok};${zsh_ok};${asdf_ok};${dev_ok};${tools_ok};${comm_ok};${office_ok};${games_ok};${others_ok};${llm_ok};${pro_ok}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
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

    # If CLI args provided, skip interactive menu
    if has_cli_args; then
        log_info "Running in CLI mode — skipping interactive menu"
        result=("${CLI_SELECTED[@]}")
    else
        prompt_for_multiselect result \
            "Brew;Git;Zsh + Oh My Zsh;ASDF (Node/Python/Java);Development;Tools;Communication;Office;Games;Others;LLM Tools;Pro Bundle" \
            "true;true;true;true;;;;;;;;" \
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
