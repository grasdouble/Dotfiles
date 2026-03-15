#!/bin/bash

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
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $1"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${RESET}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1"; }
log_skip()    { echo -e "${DIM}[SKIP]${RESET}  $1 (already installed)"; }
log_step()    { echo -e "\n${BOLD}${CYAN}━━━ [${step}/${numberStep}] $1 ${RESET}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

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
    echo -e "  ${BOLD}macOS Developer Environment Setup${RESET}  ${DIM}v2.0.0 — by Noofreuuuh${RESET}"
    echo -e "  ${DIM}https://github.com/noofreuuuh/Dotfiles${RESET}"
    echo ""
    echo -e "  ${DIM}Use ↑↓ to navigate, SPACE to toggle, ENTER to confirm${RESET}"
    echo ""
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================
check_prerequisites() {
    echo -e "${BOLD}Checking prerequisites...${RESET}\n"
    local has_error=false

    # macOS check
    if [[ "$(uname)" == "Darwin" ]]; then
        local macos_version
        macos_version=$(sw_vers -productVersion)
        log_success "macOS $macos_version detected"
    else
        log_warning "This script is designed for macOS. Some features may not work on $(uname)."
    fi

    # Architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        log_success "Apple Silicon (ARM64) detected"
    elif [[ "$arch" == "x86_64" ]]; then
        log_warning "Intel (x86_64) detected — Homebrew will install to /usr/local"
    else
        log_warning "Unknown architecture: $arch"
    fi

    # Xcode Command Line Tools
    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools installed"
    else
        log_warning "Xcode Command Line Tools not found — installing..."
        xcode-select --install 2>/dev/null
        echo -e "  ${YELLOW}→ Please complete the Xcode CLT installation popup, then re-run this script.${RESET}"
        has_error=true
    fi

    # Internet connectivity
    if curl -s --max-time 3 https://brew.sh &>/dev/null; then
        log_success "Internet connection available"
    else
        log_error "No internet connection detected — installation will likely fail."
        has_error=true
    fi

    echo ""
    if [[ "$has_error" == true ]]; then
        echo -e "${YELLOW}Some prerequisites are missing. Proceeding anyway — errors may occur.${RESET}\n"
        sleep 2
    else
        log_success "All prerequisites met.\n"
        sleep 1
    fi
}

# ============================================================================
# STEP COUNTER
# ============================================================================
let numberStep=0
let step=0
export DOTFILE_PATH=${PWD}

# ============================================================================
# INSTALL FUNCTIONS
# ============================================================================

installBrew() {
    ((step++))
    log_step "Install Brew"
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
    brew install git
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

    log_info "Cleaning previous Zsh setup..."
    rm -f "$HOME/.cache/p10k-instant-prompt-*"
    [ -d "${HOME}/.oh-my-zsh" ] && rm -Rf "${HOME}/.oh-my-zsh" && log_info "Removed old Oh My Zsh"

    log_info "Installing Zsh..."
    if [ "$(uname)" == "Darwin" ]; then
        if brew list zsh &>/dev/null; then
            brew reinstall zsh
        else
            brew install zsh
        fi
    elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
        sudo apt-get install -y zsh
    fi

    echo "export DOTFILE_PATH=\"${PWD}\"" > "${HOME}/.dotfiles-config-path.zsh"
    [ ! -f "${HOME}/.custom.zsh" ] && cp "${PWD}/zsh/custom.zsh" "${HOME}/.custom.zsh" && log_info "Created ~/.custom.zsh (personal overrides)"

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
    [ "$(uname)" == "Darwin" ] && brew install coreutils
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
    if brew list asdf &>/dev/null; then
        brew reinstall asdf
    else
        brew install asdf
    fi

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
    log_step "Install Software: Professional"
    brew install --cask visual-studio-code --appdir=/Applications/Developments
    brew install --cask iterm2 --appdir=/Applications/Developments
    brew install --cask sublime-text --appdir=/Applications/Developments
    brew install qemu colima docker
    brew install --cask rectangle --appdir=/Applications/Tools
    brew install --cask cakebrew --appdir=/Applications/Tools
    brew install --cask grandperspective --appdir=/Applications/Tools
    brew install --cask spotify --appdir=/Applications/Others
    brew install --cask vivaldi --appdir=/Applications/Others
    brew install --cask audio-hijack --appdir=/Applications/Communications
    brew install --cask whatsapp --appdir=/Applications/Communications
    brew install --cask discord --appdir=/Applications/Communications
    log_success "Software: Professional installed"
    track_result "Software: Pro" "ok"
}

installSoftwareDevelopment() {
    ((step++))
    log_step "Install Software: Development"
    brew install --cask visual-studio-code --appdir=/Applications/Developments
    brew install --cask iterm2 --appdir=/Applications/Developments
    brew install --cask wave --appdir=/Applications/Developments
    brew install --cask sublime-text --appdir=/Applications/Developments
    brew install --cask notion --appdir=/Applications/Developments
    brew install --cask anki --appdir=/Applications/Developments
    brew install qemu colima docker
    log_success "Software: Development installed"
    track_result "Software: Development" "ok"
}

installSoftwareLLM() {
    ((step++))
    log_step "Install Software: LLMs"
    brew install --cask lm-studio --appdir=/Applications/Developments
    brew install --cask chatgpt --appdir=/Applications/Developments
    brew install --cask superwhisper --appdir=/Applications/Developments
    brew install opencode
    brew install --cask opencode-desktop --appdir=/Applications/Developments
    brew install --cask antigravity --appdir=/Applications/Developments
    log_success "Software: LLMs installed"
    track_result "Software: LLM" "ok"
}

installSoftwareTools() {
    ((step++))
    log_step "Install Software: Tools"
    brew install --cask rectangle --appdir=/Applications/Tools
    brew install --cask oversight --appdir=/Applications/Tools
    brew install --cask logi-options-plus --appdir=/Applications/Tools
    brew install --cask jdownloader --appdir=/Applications/Tools
    brew install --cask background-music --appdir=/Applications/Tools
    brew install --cask grandperspective --appdir=/Applications/Tools
    brew install --cask pearcleaner --appdir=/Applications/Tools
    brew install --cask clop --appdir=/Applications/Tools
    brew install --cask protonvpn --appdir=/Applications/Tools
    brew install --cask jordanbaird-ice --appdir=/Applications/Tools
    log_success "Software: Tools installed"
    track_result "Software: Tools" "ok"
}

installSoftwareCommunication() {
    ((step++))
    log_step "Install Software: Communication"
    brew install --cask audio-hijack --appdir=/Applications/Communications
    brew install --cask slack --appdir=/Applications/Communications
    brew install --cask whatsapp --appdir=/Applications/Communications
    brew install --cask discord --appdir=/Applications/Communications
    brew install --cask signal --appdir=/Applications/Communications
    log_success "Software: Communication installed"
    track_result "Software: Communication" "ok"
}

installSoftwareOffice() {
    ((step++))
    log_step "Install Software: Office"
    brew install --cask microsoft-office --appdir=/Applications/Office
    log_success "Software: Office installed"
    track_result "Software: Office" "ok"
}

installSoftwareGames() {
    ((step++))
    log_step "Install Software: Games"
    brew install --cask --no-quarantine nvidia-geforce-now --appdir=/Applications/Games
    brew install --cask --no-quarantine epic-games --appdir=/Applications/Games
    brew install --cask --no-quarantine steam --appdir=/Applications/Games
    brew install --cask --no-quarantine prismlauncher --appdir=/Applications/Games
    brew install --cask --no-quarantine scummvm --appdir=/Applications/Games
    brew install --cask obs --appdir=/Applications/Games
    brew install --cask --no-quarantine openemu --appdir=/Applications/Games
    brew install --cask sony-ps-remote-play --appdir=/Applications/Games
    brew install --cask moonlight --appdir=/Applications/Games
    log_success "Software: Games installed"
    track_result "Software: Games" "ok"
}

installSoftwareOthers() {
    ((step++))
    log_step "Install Software: Others"
    brew install --cask --no-quarantine spotify --appdir=/Applications/Others
    brew install --cask calibre --appdir=/Applications/Others
    brew install --cask kindle-previewer --appdir=/Applications/Others
    brew install --cask send-to-kindle --appdir=/Applications/Others
    brew install --cask hakuneko --appdir=/Applications/Others
    brew install --cask affinity --appdir=/Applications/Others
    brew install --cask --no-quarantine vivaldi --appdir=/Applications/Others
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

    local ok_count=0
    local skip_count=0
    local error_count=0

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
}

# ============================================================================
# MAIN
# ============================================================================
clear
print_banner
check_prerequisites

prompt_for_multiselect result \
    "Install Brew;Install Git;Install Zsh;Install Asdf;Install Software: Development;Install Software: Tools;Install Software: Communication;Install Software: Office;Install Software: Games;Install Software: Others;Install Software: LLM;Install Software: Pro" \
    "true;true;true;true;;;;;;;;"

for option in "${result[@]}"; do
    if [[ $option == true ]]; then
        ((numberStep++))
    fi
done

echo ""
log_info "Starting installation of ${numberStep} component(s)...\n"
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
