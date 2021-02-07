numberStep=5
# Create link to NeoVim config file
echo "#### 1 / ${numberStep} - Install and configure NeoVim"
if [ "$(uname)"== "Darwin" ]; then
	brew install neovim
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	sudo apt-get install neovim
fi
[ ! -d ${HOME}/.config ] && mkdir ${HOME}/.config
[ ! -d ${HOME}/.config/nvim ] && mkdir ${HOME}/.config/nvim
[ -d ${HOME}/.config/nvim/plugged ] && rm -Rf ${HOME}/.config/nvim/plugged

# Configure zsh
echo "#### 2 / ${numberStep} - Install"
if [ "$(uname)" == "Darwin" ]; then
	echo "MAC"
elif [ "$(expr substr $(uname) 1 5)" == "Linux" ]; then
	echo "LINUX"
	sudo apt-get install zsh
fi

# Install Oh My Zsh
echo "#### 3 / ${numberStep} - Install Oh My Zsh"
[ -d ${HOME}/.oh-my-zsh ] && rm -Rf ${HOME}/.oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Add PowerLevel10k theme for Zsh
echo "### 4 / ${numberStep} - Install Theme PowerLevel10k for Zsh"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Link stuff
echo "#### 5 / ${numberStep} - Create links"
[ -f ${HOME}/.config/nvim/init.vim ] && rm ${HOME}/.config/nvim/init.vim
[ -f ${HOME}/.zshrc ] && rm ${HOME}/.zshrc
[ -f ${HOME}/.p10k.zsh ] && rm ${HOME}/.p10k.zsh
ln -s ${PWD}/nvim/init.vim ${HOME}/.config/nvim/init.vim
ln -s ${PWD}/zsh/.zshrc ${HOME}/.zshrc
ln -s ${PWD}/zsh/.p10k.zsh ${HOME}/.p10k.zsh
