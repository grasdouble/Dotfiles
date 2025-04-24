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
		brew install zsh
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install zsh
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
    # if Tools/asdf folder exists remove it
	[ -d ${DOTFILE_PATH}/Tools/asdf ] && rm -Rf ${DOTFILE_PATH}/Tools/asdf

    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install and configure ASDF"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		brew install coreutils curl git gpg gawk
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install curl git dirmngr gpg
	fi
	mkdir ${DOTFILE_PATH}/Tools
	git clone https://github.com/asdf-vm/asdf.git ${DOTFILE_PATH}/Tools/asdf
	cd ${DOTFILE_PATH}/Tools/asdf
	git checkout "$(git describe --abbrev=0 --tags)"
	cd ${DOTFILE_PATH}
	[ -d ${HOME}/.asdf ] && rm ${HOME}/.asdf 
	ln -s ${DOTFILE_PATH}/Tools/asdf ${HOME}/.asdf

	# # Add node
	# if [ "$(uname)" == "Darwin" ]; then
	# 	brew install gpg gawk
	# elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	# 	sudo apt-get install dirmngr gpg
	# fi

	. $HOME/.asdf/asdf.sh
	
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Add ASDF plugins"
	echo "############################################################################"
	zsh -c "asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git"
	# zsh -c '${ASDF_DATA_DIR:=${DOTFILE_PATH}/Tools/asdf}/plugins/nodejs/bin/import-release-team-keyring'
	zsh -c "asdf install nodejs latest"
	zsh -c "asdf global nodejs latest"

	zsh -c "asdf plugin-add pnpm https://github.com/jonathanmorley/asdf-pnpm.git"
	zsh -c "asdf install pnpm latest"
	zsh -c "asdf global pnpm latest"

	zsh -c "asdf plugin-add yarn https://github.com/twuni/asdf-yarn.git"
	zsh -c "asdf install yarn latest"
	zsh -c "asdf global yarn latest"

	zsh -c "asdf plugin-add python"

	zsh -c "asdf plugin-add java https://github.com/halcyon/asdf-java.git"
	zsh -c "asdf install java latest:adoptopenjdk-11"
	zsh -c "asdf global java latest:adoptopenjdk-11"

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
	brew install --cask docker --appdir=/Applications/Developments
	brew install --cask notion --appdir=/Applications/Developments
	brew install --cask anki --appdir=/Applications/Developments
	brew install --cask lm-studio --appdir=/Applications/Developments
	brew install --cask mylio --appdir=/Applications/Developments
	brew install --cask ollama --appdir=/Applications/Developments
}

installSofwareLLM(){
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: LLMs"
	echo "############################################################################"
	brew install ollama
	ollama pull llama3:instruct
	ollama pull llama3:latest

}

installSoftwareTools() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Tools"
	echo "############################################################################"
	brew install --cask rectangle --appdir=/Applications/Tools
	brew install --cask cakebrew --appdir=/Applications/Tools
	brew install --cask raycast --appdir=/Applications/Tools
	brew install --cask screens-connect --appdir=/Applications/Tools
	brew install --cask oversight --appdir=/Applications/Tools #appdir not working
	brew install --cask logi-options-plus --appdir=/Applications/Tools #appdir not working
	brew install --cask jdownloader --appdir=/Applications/Tools #appdir not working
	## brew install --cask battery --appdir=/Applications/Tools # replace by Aldente via setapp
	brew install --cask background-music --appdir=/Applications/Tools #still maintained?
	brew install --cask logitech-g-hub --appdir=/Applications/Tools
	brew install --cask grandperspective --appdir=/Applications/Tools
}

installSoftwareCommunication() {
    ((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software: Communication"
	echo "############################################################################"
	brew install --cask slack --appdir=/Applications/Communications
	brew install --cask whatsapp --appdir=/Applications/Communications
	brew install --cask discord --appdir=/Applications/Communications
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
	#brew install --cask gog-galaxy --appdir=/Applications/Games
	## brew install --cask battle-net --appdir=/Applications/Games # need extra action: check logs to run setup
	brew install --cask --no-quarantine prismlauncher --appdir=/Applications/Games
	brew install --cask whisky --appdir=/Applications/Games
	#brew install --cask crossover --appdir=/Applications/Games
	brew install --cask --no-quarantine scummvm --appdir=/Applications/Games
	brew install --cask obs --appdir=/Applications/Games
	brew install --cask --no-quarantine openemu --appdir=/Applications/Games
	brew install --cask sony-ps-remote-play --appdir=/Applications/Games #appdir not working (move it manually?? https://github.com/kyleneideck/BackgroundMusic)
	brew install --cask chiaki --appdir=/Applications/Games
	brew install --cask moonlight --appdir=/Applications/Games
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
	brew install --cask affinity-designer --appdir=/Applications/Others
	brew install --cask affinity-photo --appdir=/Applications/Others
	brew install --cask affinity-publisher --appdir=/Applications/Others
	brew install --cask pixelorama --appdir=/Applications/Others
	brew install --cask arc --appdir=/Applications/Others
	brew install --cask --no-quarantine vivaldi --appdir=/Applications/Others
}


prompt_for_multiselect result "Install brew;install Git;install Zsh;install Asdf;install Software: Development;install Software: Tools;install Software: Communication;install Software: Office;install Software: Games;install Software: Others" "true;true;true;true;;;;;;"

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
        esac
    fi
done