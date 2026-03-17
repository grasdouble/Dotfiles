# zsh_preload.zsh — Oh My Zsh pre-load overrides
# Sourced directly from ~/.zshrc (injected by the dotfiles installer).
# DOTFILE_PATH is exported in ~/.zshrc before this file is sourced.
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
