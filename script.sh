numberStep=5
let step=0


echo "############################################################################"
((step++))
echo "#### ${step} / ${numberStep} - Init basic stuff"
echo "export DOTFILE_PATH=\"${PWD}\"" > ${HOME}/.dotfiles-config-path.zsh
[ ! -f ${HOME}/.custom.zsh ] && cp ${PWD}/zsh/custom.zsh ${HOME}/.custom.zsh

echo "############################################################################"
((step++))
echo "#### ${step} / ${numberStep} - Install and configure NeoVim"
[ -d ${HOME}/.config/nvim ] && rm -Rf ${HOME}/.config/nvim
mkdir -p ${HOME}/.config/nvim
ln -s ${PWD}/nvim/init.vim ${HOME}/.config/nvim/init.vim
if [ "$(uname)" == "Darwin" ]; then
	brew install neovim
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	sudo apt-get install neovim
fi

echo "############################################################################"
((step++))
echo "#### ${step} / ${numberStep} - Install ZSH"
if [ "$(uname)" == "Darwin" ]; then
	brew install zsh
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	echo "LINUX"
	sudo apt-get install zsh
fi

echo "############################################################################"
((step++))
echo "#### ${step} / ${numberStep} - Install Oh My Zsh"
[ -d ${HOME}/.oh-my-zsh ] && rm -Rf ${HOME}/.oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "############################################################################"
((step++))
echo "#### ${step} / ${numberStep} - Create link to zsh config"
[ -f ${HOME}/.zshrc ] && rm ${HOME}/.zshrc
ln -s ${PWD}/zsh/zshrc ${HOME}/.zshrc

echo "############################################################################"
((step++))
echo "### ${step} / ${numberStep} - Install Plugins for Zsh"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
if [ "$(uname)" == "Darwin" ]; then
	brew install coreutils
	git clone https://github.com/supercrabtree/k ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	git clone https://github.com/supercrabtree/k ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/k
fi

echo "############################################################################"
((step++))
echo "### ${step} / ${numberStep} - Install Theme PowerLevel10k for Zsh"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo "############################################################################"
((step++))
echo "#### 5 / ${numberStep} - Install Nerd Font"
if [ "$(uname)" == "Darwin" ]; then
	cd ${HOME}/Library/Fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	[ ! -d ${HOME}/.local/share/fonts ] && mkdir -p ${HOME}/.local/share/fonts
	cd ${HOME}/.local/share/fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
fi
