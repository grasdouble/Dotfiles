#!/bin/bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# add a function to the script: prompt_for_multiselect
source "${SCRIPT_DIR}/prompt_for_multiselect.sh"

# Color definitions for better CLI experience
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Helper functions for better CLI output
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${MAGENTA}► Step ${step}/${numberStep}:${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_section() {
    echo ""
    echo -e "${CYAN}▸ $1${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
${BOLD}Dotfiles Setup Script${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

This script will help you set up your development environment with:
  • Brew - Package manager for macOS
  • Git - Version control system
  • Zsh - Shell with Oh My Zsh framework
  • ASDF - Runtime version manager
  • Neovim - Text editor
  • Various development tools and applications

${BOLD}Usage:${NC}
  ./main.sh [OPTIONS]

${BOLD}Options:${NC}
  -h, --help     Show this help message
  -y, --yes      Skip interactive selection (install recommended defaults)

${BOLD}Interactive Mode:${NC}
  Without options, you'll see an interactive menu to select what to install.
  Use arrow keys to navigate, space to select/deselect, enter to confirm.

EOF
}

# Parse command line arguments
SKIP_INTERACTIVE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -y|--yes)
            SKIP_INTERACTIVE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# 	echo "############################################################################"
# 	echo "#### INIT STEP COUNTER"
((numberStep=0)) # will be defined by result of prompt_for_multiselect
((step=0))
# 	echo "############################################################################"

export DOTFILE_PATH=${PWD}

# Track installed components for summary
declare -a INSTALLED_COMPONENTS=()
declare -a SKIPPED_COMPONENTS=()
declare -a FAILED_COMPONENTS=()

installBrew() {
	((step++))
	print_header "Install Brew"
	print_step "Installing Homebrew package manager"
	
    # if brew is not installed install it else skip
	if ! command -v brew &> /dev/null; then
		print_info "Installing Brew..."
		if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
			print_success "Brew installed successfully"
			INSTALLED_COMPONENTS+=("Brew")
		else
			print_error "Failed to install Brew"
			FAILED_COMPONENTS+=("Brew")
			return 1
		fi
	else
		print_warning "Brew already installed, skipping"
		SKIPPED_COMPONENTS+=("Brew")
	fi
}

installGit() {
	((step++))
	print_header "Install Git"
	print_step "Installing Git version control system"
	
	if brew install git; then
		print_success "Git installed successfully"
		echo ""
		# Use printf for more reliable color output
		printf "%b" "${CYAN}What is your Git username?${NC} "
		read -r USERNAME
		echo "";
		git config --global user.name "$USERNAME"
		printf "%b" "${CYAN}What is your Git email?${NC} "
		read -r EMAIL
		echo "";
		git config --global user.email "$EMAIL"
		print_success "Git configured with username: $USERNAME and email: $EMAIL"
		INSTALLED_COMPONENTS+=("Git")
	else
		print_error "Failed to install Git"
		FAILED_COMPONENTS+=("Git")
		return 1
	fi
}

installZsh() {
    ((step++))
	print_header "Install ZSH & Oh My Zsh"
	print_step "Installing Zsh shell with Oh My Zsh framework"
	
	print_section "Cleaning existing ZSH installation"
    # clean zsh theme cache
    print_info "Cleaning zsh theme cache"
	rm -f "$HOME"/.cache/p10k-instant-prompt-*
    # clean oh-my-zsh
    print_info "Cleaning oh-my-zsh"
    [ -d "${HOME}/.oh-my-zsh" ] && rm -Rf "${HOME}/.oh-my-zsh"
    # clean zsh config
    # echo "-- Clean zsh config"
    # [ -f ${HOME}/.custom.zsh ] && rm ${HOME}/.custom.zsh

	print_section "Installing ZSH"
	if [ "$(uname)" == "Darwin" ]; then
		if brew list zsh &>/dev/null; then
			brew reinstall zsh
		else
			brew install zsh
		fi
	elif [[ "$(uname)" == Linux* ]]; then
		sudo apt-get install -y zsh
	fi
	print_success "Zsh installed"

    # save script path (supposing we run it from the dotfiles root)
    echo "export DOTFILE_PATH=\"${PWD}\"" > "${HOME}/.dotfiles-config-path.zsh"
    # if link to custom.zsh is not there create it
	[ ! -f "${HOME}/.custom.zsh" ] && cp "${PWD}/zsh/custom.zsh" "${HOME}/.custom.zsh"

	print_section "Installing Oh My Zsh"
	if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
		print_success "Oh My Zsh installed"
	else
		print_warning "Oh My Zsh installation encountered an issue"
	fi

	print_section "Creating symbolic links to zsh config"
	[ -f "${HOME}/.zshrc" ] && rm "${HOME}/.zshrc"
	ln -s "${PWD}/zsh/zshrc" "${HOME}/.zshrc"
	[ -f "${HOME}/.zlogin" ] && rm "${HOME}/.zlogin"
	ln -s "${PWD}/zsh/zlogin" "${HOME}/.zlogin"
	print_success "Config files linked"

	print_section "Installing Zsh plugins"
	[ ! -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] && \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" && \
		print_success "Installed zsh-syntax-highlighting"
	[ ! -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] && \
		git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" && \
		print_success "Installed zsh-autosuggestions"
	if [ "$(uname)" == "Darwin" ]; then
		brew install coreutils
	fi
	[ ! -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k" ] && \
		git clone https://github.com/supercrabtree/k "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k" && \
		print_success "Installed k plugin"

	print_section "Installing PowerLevel10k theme"
	[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ] && \
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && \
		print_success "PowerLevel10k theme installed"
	

	print_section "Installing Nerd Font"
	if [ "$(uname)" == "Darwin" ]; then
		if (cd "${HOME}/Library/Fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf); then
			print_success "Nerd Font installed"
		else
			print_warning "Nerd Font installation failed"
		fi
	elif [[ "$(uname)" == Linux* ]]; then
		[ ! -d "${HOME}/.local/share/fonts" ] && mkdir -p "${HOME}/.local/share/fonts"
		if (cd "${HOME}/.local/share/fonts" && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf); then
			print_success "Nerd Font installed"
		else
			print_warning "Nerd Font installation failed"
		fi
	fi
	
	INSTALLED_COMPONENTS+=("Zsh + Oh My Zsh")
}

installAsdf() {
	((step++))
	print_header "Install ASDF"
	print_step "Installing ASDF version manager"
	
	print_section "Installing ASDF"
	if brew list asdf &>/dev/null; then
		brew reinstall asdf
	else
		brew install asdf
	fi
	print_success "ASDF installed"

	# # Add node
	# if [ "$(uname)" == "Darwin" ]; then
	# 	brew install gpg gawk
	# elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	# 	sudo apt-get install dirmngr gpg
	# fi
	
    ((step++))
	print_section "Adding ASDF plugins"
	
	print_info "Adding nodejs plugin..."
	zsh -c "asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git" || true
	zsh -c "asdf install nodejs latest"
	print_success "Node.js installed"

	print_info "Adding pnpm plugin..."
	zsh -c "asdf plugin add pnpm https://github.com/jonathanmorley/asdf-pnpm.git" || true
	zsh -c "asdf install pnpm latest"
	print_success "pnpm installed"

	print_info "Adding python plugin..."
	zsh -c "asdf plugin add python" || true
	print_success "Python plugin added"

	print_info "Adding java plugin..."
	zsh -c "asdf plugin add java https://github.com/halcyon/asdf-java.git" || true
	zsh -c "asdf install java adoptopenjdk-11.0.27+6"
	print_success "Java installed"
	
	INSTALLED_COMPONENTS+=("ASDF + Node.js + pnpm + Java")
}

installSoftwarePro(){
    ((step++))
	print_header "Install Professional Software"
	print_step "Installing professional development applications"
	
	print_info "Installing applications via Homebrew..."
	brew install --cask visual-studio-code --appdir=/Applications/Developments
	brew install --cask iterm2 --appdir=/Applications/Developments
	brew install --cask sublime-text --appdir=/Applications/Developments
	brew install --cask docker --appdir=/Applications/Developments
	brew install --cask mylio --appdir=/Applications/Developments
	brew install --cask rectangle --appdir=/Applications/Tools
	brew install --cask cakebrew --appdir=/Applications/Tools
	brew install --cask grandperspective --appdir=/Applications/Tools
	brew install --cask --no-quarantine spotify --appdir=/Applications/Others
	brew install --cask --no-quarantine vivaldi --appdir=/Applications/Others
	brew install --cask --no-quarantine whatsapp --appdir=/Applications/Communications
	brew install --cask --no-quarantine discord --appdir=/Applications/Communications
	
	print_success "Professional software installed"
	INSTALLED_COMPONENTS+=("Professional Software")
}

installSoftwareDevelopment(){
    ((step++))
	print_header "Install Development Software"
	print_step "Installing development applications"
	
	print_info "Installing development tools..."
	brew install --cask visual-studio-code --appdir=/Applications/Developments
	brew install --cask iterm2 --appdir=/Applications/Developments
	brew install --cask wave --appdir=/Applications/Developments
	brew install --cask sublime-text --appdir=/Applications/Developments
	brew install --cask docker --appdir=/Applications/Developments
	brew install --cask notion --appdir=/Applications/Developments
	brew install --cask anki --appdir=/Applications/Developments
	brew install --cask mylio --appdir=/Applications/Developments
	
	print_success "Development software installed"
	INSTALLED_COMPONENTS+=("Development Software")
}

installSofwareLLM(){
    ((step++))
	print_header "Install LLM Software"
	print_step "Installing Large Language Model tools"
	
	print_info "Installing LM Studio and Ollama..."
	brew install --cask lm-studio --appdir=/Applications/Developments
	brew install --cask ollama --appdir=/Applications/Developments
	brew install ollama
	
	print_info "Pulling Llama3 models..."
	ollama pull llama3:instruct
	ollama pull llama3:latest
	
	print_success "LLM software installed"
	INSTALLED_COMPONENTS+=("LLM Tools")
}

installSoftwareTools() {
    ((step++))
	print_header "Install Utility Tools"
	print_step "Installing utility applications"
	
	print_info "Installing system tools..."
	brew install --cask rectangle --appdir=/Applications/Tools
	brew install --cask oversight --appdir=/Applications/Tools
	brew install --cask logi-options-plus --appdir=/Applications/Tools
	brew install --cask background-music --appdir=/Applications/Tools
	brew install --cask grandperspective --appdir=/Applications/Tools
	brew install --cask pearcleaner --appdir=/Applications/Tools
	brew install --cask clop --appdir=/Applications/Tools
	
	print_success "Utility tools installed"
	INSTALLED_COMPONENTS+=("Utility Tools")
}

installSoftwareCommunication() {
    ((step++))
	print_header "Install Communication Software"
	print_step "Installing communication applications"
	
	print_info "Installing communication tools..."
	brew install --cask slack --appdir=/Applications/Communications
	brew install --cask whatsapp --appdir=/Applications/Communications
	brew install --cask discord --appdir=/Applications/Communications
	
	print_success "Communication software installed"
	INSTALLED_COMPONENTS+=("Communication Software")
}

installSoftwareOffice() {
    ((step++))
	print_header "Install Office Software"
	print_step "Installing Microsoft Office"
	
	print_info "Installing Microsoft Office..."
	brew install --cask microsoft-office --appdir=/Applications/Office
	
	print_success "Office software installed"
	INSTALLED_COMPONENTS+=("Office Software")
}

installSoftwareGames() {
    ((step++))
	print_header "Install Gaming Software"
	print_step "Installing gaming applications"
	
	print_info "Installing gaming platforms and tools..."
	brew install --cask --no-quarantine nvidia-geforce-now --appdir=/Applications/Games
	brew install --cask --no-quarantine epic-games --appdir=/Applications/Games
	brew install --cask --no-quarantine steam --appdir=/Applications/Games
	brew install --cask --no-quarantine prismlauncher --appdir=/Applications/Games
	brew install --cask --no-quarantine scummvm --appdir=/Applications/Games
	brew install --cask obs --appdir=/Applications/Games
	brew install --cask --no-quarantine openemu --appdir=/Applications/Games
	brew install --cask sony-ps-remote-play --appdir=/Applications/Games
	brew install --cask moonlight --appdir=/Applications/Games
	
	print_success "Gaming software installed"
	INSTALLED_COMPONENTS+=("Gaming Software")
}

installSoftwareOthers() {
    ((step++))
	print_header "Install Other Software"
	print_step "Installing miscellaneous applications"
	
	print_info "Installing media and other applications..."
	brew install --cask --no-quarantine spotify --appdir=/Applications/Others
	brew install --cask calibre --appdir=/Applications/Others
	brew install --cask kindle-previewer --appdir=/Applications/Others
	brew install --cask send-to-kindle --appdir=/Applications/Others
	brew install --cask hakuneko --appdir=/Applications/Others
	brew install --cask affinity --appdir=/Applications/Others
	brew install --cask --no-quarantine vivaldi --appdir=/Applications/Others
	
	print_success "Other software installed"
	INSTALLED_COMPONENTS+=("Other Software")
}


# Display welcome banner
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                        🚀 DOTFILES SETUP SCRIPT 🚀                           ║
║                                                                              ║
║              Configure your development environment with ease                ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo ""

if [ "$SKIP_INTERACTIVE" = true ]; then
    print_info "Running in non-interactive mode with default selections"
    # Set default selections (brew, git, zsh, asdf enabled)
    result=(true true true true false false false false false false false false)
else
    print_info "Select the components you want to install:"
    echo ""
    prompt_for_multiselect result "Install brew;install Git;install Zsh;install Asdf;install Software: Development;install Software: Tools;install Software: Communication;install Software: Office;install Software: Games;install Software: Others;install Software: LLM;install Software: Pro" "true;true;true;true;;;;;;;;"
fi

for option in "${result[@]}"; do
    if [[ $option == true ]]; then
        ((numberStep++))
    fi
done

if [ $numberStep -eq 0 ]; then
    print_warning "No components selected. Exiting."
    exit 0
fi

print_info "Total steps to execute: $numberStep"
echo ""
sleep 1

# Call the functions depending on the result
for i in "${!result[@]}"; do
    if [[ ${result[$i]} == true ]]; then
        case $i in
            0) installBrew ;;
            1) installGit ;;
            2) installZsh ;;
            3) installAsdf ;;
            4) installSoftwareDevelopment ;;
            5) installSoftwareTools ;;
            6) installSoftwareCommunication ;;
            7) installSoftwareOffice ;;
            8) installSoftwareGames ;;
            9) installSoftwareOthers ;;
            10) installSofwareLLM ;;
			11) installSoftwarePro ;;
        esac
    fi
done

# Display summary
echo ""
print_header "Installation Summary"
echo ""

if [ ${#INSTALLED_COMPONENTS[@]} -gt 0 ]; then
    echo -e "${BOLD}${GREEN}✓ Successfully Installed:${NC}"
    for component in "${INSTALLED_COMPONENTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $component"
    done
    echo ""
fi

if [ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}⊘ Skipped (already installed):${NC}"
    for component in "${SKIPPED_COMPONENTS[@]}"; do
        echo -e "  ${YELLOW}⊘${NC} $component"
    done
    echo ""
fi

if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo -e "${BOLD}${RED}✗ Failed to Install:${NC}"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo -e "  ${RED}✗${NC} $component"
    done
    echo ""
    print_error "Some components failed to install. Please check the output above for details."
    exit 1
else
    echo -e "${BOLD}${GREEN}🎉 All selected components installed successfully!${NC}"
    echo ""
    print_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Configure PowerLevel10k theme by running: p10k configure"
    echo "  3. Customize your settings in ~/.custom.zsh"
    echo ""
    print_success "Setup complete! Happy coding! 🚀"
fi