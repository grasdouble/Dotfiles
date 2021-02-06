# Create link to NeoVim config file
[ ! -d ${HOME}/.config ] && mkdir ${HOME}/.config
[ ! -d ${HOME}/.config/nvim ] && mkdir ${HOME}/.config/nvim
[ -d ${HOME}/.config/nvim/plugged ] && rm -Rf ${HOME}/.config/nvim/plugged
[ -f ${HOME}/.config/nvim/init.vim ] && rm ${HOME}/.config/nvim/init.vim
ln -s ${PWD}/nvim/init.vim ${HOME}/.config/nvim/init.vim
