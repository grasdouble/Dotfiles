numberStep=11
let step=0

initBasicStuff() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Init basic stuff"
	echo "############################################################################"
	rm -f $HOME/.cache/p10k-instant-prompt-*
	export DOTFILE_PATH=${PWD}
	echo "export DOTFILE_PATH=\"${PWD}\"" > ${HOME}/.dotfiles-config-path.zsh
	[ ! -f ${HOME}/.custom.zsh ] && cp ${PWD}/zsh/custom.zsh ${HOME}/.custom.zsh
	[ -d ${DOTFILE_PATH}/Tools ] && rm -Rf ${DOTFILE_PATH}/Tools
	mkdir ${DOTFILE_PATH}/Tools

	if ! command -v brew &> /dev/null; then
		echo "Installing Brew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		echo "Brew detected. install skipped"
	fi
	brew install git python3
	pip3 install neovim
}

configureGit() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Configure git"
	echo "############################################################################"
	read -p "What is your username? " USERNAME;
	echo "";
	git config --global user.name $USERNAME
	read -p "What is your email? " EMAIL;
	echo "";
	git config --global user.email $EMAIL
}

installNeovim() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install and configure NeoVim"
	echo "############################################################################"
	[ -d ${HOME}/.config/nvim ] && rm -Rf ${HOME}/.config/nvim 
	mkdir -p ${HOME}/.config/nvim
	ln -s ${PWD}/nvim/init.vim ${HOME}/.config/nvim/init.vim
	if [ "$(uname)" == "Darwin" ]; then
		brew install neovim
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install neovim
	fi

	zsh -c "yarn global add neovim"
}

installZsh() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install ZSH"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		brew install zsh
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install zsh
	fi

	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Oh My Zsh"
	echo "############################################################################"
	[ -d ${HOME}/.oh-my-zsh ] && rm -Rf ${HOME}/.oh-my-zsh
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Create link to zsh config"
	echo "############################################################################"
	[ -f ${HOME}/.zshrc ] && rm ${HOME}/.zshrc
	ln -s ${PWD}/zsh/zshrc ${HOME}/.zshrc

	((step++))
	echo "############################################################################"
	echo "### ${step} / ${numberStep} - Install Plugins for Zsh"
	echo "############################################################################"
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	if [ "$(uname)" == "Darwin" ]; then
		brew install coreutils
	fi
	git clone https://github.com/supercrabtree/k ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k

	((step++))
	echo "############################################################################"
	echo "### ${step} / ${numberStep} - Install Theme PowerLevel10k for Zsh"
	echo "############################################################################"
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Nerd Font"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		cd ${HOME}/Library/Fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		[ ! -d ${HOME}/.local/share/fonts ] && mkdir -p ${HOME}/.local/share/fonts
		cd ${HOME}/.local/share/fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
	fi
}


installAsdf() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install and configure ASDF"
	echo "############################################################################"
	if [ "$(uname)" == "Darwin" ]; then
		brew install coreutils curl git gpg gawk
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install curl git dirmngr gpg
	fi
	git clone https://github.com/asdf-vm/asdf.git ${DOTFILE_PATH}/Tools/asdf
	cd ${DOTFILE_PATH}/Tools/asdf
	git checkout "$(git describe --abbrev=0 --tags)"
	cd ${DOTFILE_PATH}
	[ -d ${HOME}/.asdf ] && unlink ${HOME}/.asdf 
	ln -s ${DOTFILE_PATH}/Tools/asdf ${HOME}/.asdf

	# Add node
	if [ "$(uname)" == "Darwin" ]; then
		brew install gpg gawk
	elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
		sudo apt-get install dirmngr gpg
	fi

	. $HOME/.asdf/asdf.sh
	
	zsh -c "asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git"
	zsh -c '${ASDF_DATA_DIR:=${DOTFILE_PATH}/Tools/asdf}/plugins/nodejs/bin/import-release-team-keyring'
	zsh -c "asdf install nodejs latest"
	zsh -c "asdf global nodejs latest"

	zsh -c "asdf plugin-add yarn"
	zsh -c "asdf install yarn latest"
	zsh -c "asdf global yarn latest"
}

installSoftware() {
	((step++))
	echo "############################################################################"
	echo "#### ${step} / ${numberStep} - Install Software"
	echo "############################################################################"
	brew install --cask visual-studio-code
	brew install --cask cakebrew
	brew install --cask discord
	brew install --cask iterm2
}

doIt() {
	initBasicStuff;
	configureGit;
	installZsh;
	installAsdf;
	installNeovim;
	installSoftware;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt;
else
	read -p "I'm about to change the configuration files placed in your home directory. Do you want to continue? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
