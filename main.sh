#!/bin/bash

# add a function to the script: prompt_for_multiselect
source ./prompt_for_multiselect.sh

# 	echo "############################################################################"
# 	echo "#### INIT STEP COUNTER"
let numberStep=0 # will be defined by result of prompt_for_multiselect
let step=0
# 	echo "############################################################################"

export DOTFILE_PATH=${PWD}

installBrew() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Brew"
	echo "############################################################################"
    # if brew is not installed install it else skip
	if ! command -v brew &> /dev/null; then
		echo "Installing Brew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		echo "Brew detected. install skipped"
	fi
}

installGit() {
	((step++))
    echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install git"
	echo "############################################################################"
    brew install git
	read -p "What is your username? " USERNAME;
	echo "";
	git config --global user.name $USERNAME
	read -p "What is your email? " EMAIL;
	echo "";
	git config --global user.email $EMAIL
}

installZsh() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install ZSH"
	echo "############################################################################"
    echo "############################################################################"
	echo "#### Clean Existing ZSH "
	echo "############################################################################"
    # clean zsh theme cache
    echo "-- Clean zsh theme cache"
	rm -f $HOME/.cache/p10k-instant-prompt-*
    # clean oh-my-zsh
    echo "-- Clean oh-my-zsh"
    [ -d ${HOME}/.oh-my-zsh ] && rm -Rf ${HOME}/.oh-my-zsh
    # clean zsh config
    # echo "-- Clean zsh config"
    # [ -f ${HOME}/.custom.zsh ] && rm ${HOME}/.custom.zsh

	echo "############################################################################"
	echo "#### Install ZSH"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		if brew list zsh &>/dev/null; then
			brew reinstall zsh
		else
			brew install zsh
		fi
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install -y zsh
	fi

    # save script path (supposing we run it from the dotfiles root)
    echo "export DOTFILE_PATH=\"${PWD}\"" > ${HOME}/.dotfiles-config-path.zsh
    # if link to custom.zsh is not there create it
	[ ! -f ${HOME}/.custom.zsh ] && cp ${PWD}/zsh/custom.zsh ${HOME}/.custom.zsh

	echo "############################################################################"
	echo "#### Install Oh My Zsh"
	echo "############################################################################"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

	echo "############################################################################"
	echo "#### Create link to zsh config"
	echo "############################################################################"
	[ -f ${HOME}/.zshrc ] && rm ${HOME}/.zshrc
	ln -s ${PWD}/zsh/zshrc ${HOME}/.zshrc
	[ -f ${HOME}/.zlogin ] && rm ${HOME}/.zlogin
	ln -s ${PWD}/zsh/zlogin ${HOME}/.zlogin

	echo "############################################################################"
	echo "### Install Plugins for Zsh"
	echo "############################################################################"
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	if [ "$(uname)" == "Darwin" ]; then
		brew install coreutils
	fi
	git clone https://github.com/supercrabtree/k ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k

	echo "############################################################################"
	echo "### Install Theme PowerLevel10k for Zsh"
	echo "############################################################################"
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
	

	echo "############################################################################"
	echo "#### Install Nerd Font"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		cd ${HOME}/Library/Fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		[ ! -d ${HOME}/.local/share/fonts ] && mkdir -p ${HOME}/.local/share/fonts
		cd ${HOME}/.local/share/fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/DroidSansMNerdFontMono-Regular.otf
	fi
}

installAsdf() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Clean Existing ASDF"
	echo "############################################################################"
	if brew list asdf &>/dev/null; then
		brew reinstall asdf
	else
		brew install asdf
	fi

	# # Add node
	# if [ "$(uname)" == "Darwin" ]; then
	# 	brew install gpg gawk
	# elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	# 	sudo apt-get install dirmngr gpg
	# fi
	
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Add ASDF plugins"
	echo "############################################################################"
	zsh -c "asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git"
	# zsh -c '${ASDF_DATA_DIR:=${DOTFILE_PATH}/Tools/asdf}/plugins/nodejs/bin/import-release-team-keyring'
	zsh -c "asdf install nodejs latest"

	zsh -c "asdf plugin add pnpm https://github.com/jonathanmorley/asdf-pnpm.git"
	zsh -c "asdf install pnpm latest"

	# zsh -c "asdf plugin add yarn https://github.com/twuni/asdf-yarn.git"
	# zsh -c "asdf install yarn latest"
	# zsh -c "asdf global yarn latest"

	zsh -c "asdf plugin add python"

	zsh -c "asdf plugin add java https://github.com/halcyon/asdf-java.git"
	# if needed to change the version asdf list all java |grep adoptopenjdk-11
	zsh -c "asdf install java adoptopenjdk-11.0.27+6"
}

installSoftwarePro(){
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Professional"
	echo "############################################################################"
	brew install --cask visual-studio-code --appdir=/Applications/Developments
	brew install --cask iterm2 --appdir=/Applications/Developments
	brew install --cask sublime-text --appdir=/Applications/Developments
	brew install qemu colima docker # Docker (check aliases to start it)
	# Tools
	brew install --cask rectangle --appdir=/Applications/Tools
	brew install --cask cakebrew --appdir=/Applications/Tools
	brew install --cask grandperspective --appdir=/Applications/Tools
	# Other
	brew install --cask spotify --appdir=/Applications/Others
	brew install --cask vivaldi --appdir=/Applications/Others
	# Communication
	brew install --cask audio-hijack --appdir=/Applications/Communications
	brew install --cask whatsapp --appdir=/Applications/Communications
	brew install --cask discord --appdir=/Applications/Communications
}

installSoftwareDevelopment(){
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Developments"
	echo "############################################################################"
	brew install --cask visual-studio-code --appdir=/Applications/Developments
	brew install --cask iterm2 --appdir=/Applications/Developments
	brew install --cask wave --appdir=/Applications/Developments
	brew install --cask sublime-text --appdir=/Applications/Developments
	brew install --cask notion --appdir=/Applications/Developments
	brew install --cask anki --appdir=/Applications/Developments
	brew install qemu colima docker # Docker (check aliases to start it)

}

installSofwareLLM(){
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: LLMs"
	echo "############################################################################"
	brew install --cask lm-studio --appdir=/Applications/Developments
	brew install --cask chatgpt --appdir=/Applications/Developments
	brew install --cask superwhisper --appdir=/Applications/Developments
	brew install opencode 
	brew install --cask opencode-desktop --appdir=/Applications/Developments
	brew install --cask antigravity --appdir=/Applications/Developments
	# brew install --cask ollama --appdir=/Applications/Developments
	# brew install ollama
	# ollama pull llama3:instruct
	# ollama pull llama3:latest

}

installSoftwareTools() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Tools"
	echo "############################################################################"
	brew install --cask rectangle --appdir=/Applications/Tools
	# brew install --cask raycast --appdir=/Applications/Tools
	brew install --cask oversight --appdir=/Applications/Tools #appdir not working
	brew install --cask logi-options-plus --appdir=/Applications/Tools #appdir not working
	brew install --cask jdownloader --appdir=/Applications/Tools #appdir not working
	## brew install --cask battery --appdir=/Applications/Tools # replace by Aldente via setapp
	brew install --cask background-music --appdir=/Applications/Tools #still maintained? yes in 2025
	brew install --cask grandperspective --appdir=/Applications/Tools
	brew install --cask pearcleaner --appdir=/Applications/Tools
	brew install --cask clop --appdir=/Applications/Tools
	brew install --cask protonvpn --appdir=/Applications/Tools
	brew install --cask jordanbaird-ice --appdir=/Applications/Tools
}

installSoftwareCommunication() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Communication"
	echo "############################################################################"
	brew install --cask audio-hijack --appdir=/Applications/Communications
	brew install --cask slack --appdir=/Applications/Communications
	brew install --cask whatsapp --appdir=/Applications/Communications
	brew install --cask discord --appdir=/Applications/Communications
	brew install --cask signal --appdir=/Applications/Communications
	#brew install --cask legcord --appdir=/Applications/Communications
}

installSoftwareOffice() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Office"
	echo "############################################################################"
	brew install --cask microsoft-office --appdir=/Applications/Office #appdir not working
}

installSoftwareGames() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Games"
	echo "############################################################################"
	brew install --cask --no-quarantine nvidia-geforce-now --appdir=/Applications/Games
	brew install --cask --no-quarantine epic-games --appdir=/Applications/Games
	brew install --cask --no-quarantine steam --appdir=/Applications/Games
	brew install --cask --no-quarantine prismlauncher --appdir=/Applications/Games
	brew install --cask --no-quarantine scummvm --appdir=/Applications/Games
	brew install --cask obs --appdir=/Applications/Games
	brew install --cask --no-quarantine openemu --appdir=/Applications/Games
	brew install --cask sony-ps-remote-play --appdir=/Applications/Games #appdir not working (move it manually)
	brew install --cask moonlight --appdir=/Applications/Games
	# brew install --cask whisky --appdir=/Applications/Games # deprecated or disabled
	# brew install --cask chiaki --appdir=/Applications/Games # deprecated or disabled
}

installSoftwareOthers() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Others"
	echo "############################################################################"
	brew install --cask --no-quarantine spotify --appdir=/Applications/Others
	brew install --cask calibre --appdir=/Applications/Others
	brew install --cask kindle-previewer --appdir=/Applications/Others
	brew install --cask send-to-kindle --appdir=/Applications/Others
	brew install --cask hakuneko --appdir=/Applications/Others
	brew install --cask affinity --appdir=/Applications/Others
	brew install --cask --no-quarantine vivaldi --appdir=/Applications/Others
	# brew install --cask pixelorama --appdir=/Applications/Others # deprecated or disabled
}


prompt_for_multiselect result "Install brew;install Git;install Zsh;install Asdf;install Software: Development;install Software: Tools;install Software: Communication;install Software: Office;install Software: Games;install Software: Others;install Software: LLM;install Software: Pro" "true;true;true;true;;;;;;;;"

for option in "${result[@]}"; do
    if [[ $option == true ]]; then
        ((numberStep++))
    fi
done
echo numberStep: $numberStep
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