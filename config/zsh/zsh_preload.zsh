# zsh_preload.zsh — Oh My Zsh pre-load overrides
# Symlinked to ~/.zsh_preload.zsh by the dotfiles installer.
# Injected into ~/.zshrc just before `source $ZSH/oh-my-zsh.sh`.
#
# Overrides the OMZ defaults (theme, plugins, options) set earlier
# in the OMZ-generated ~/.zshrc.

# Enable Powerlevel10k instant prompt. Must stay at the top.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_THEME="powerlevel10k/powerlevel10k"
ENABLE_CORRECTION="true"
HIST_STAMPS="dd/mm/yyyy"
plugins=(git vscode k zsh-autosuggestions zsh-syntax-highlighting)
