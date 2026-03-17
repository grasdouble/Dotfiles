# zsh_postload.zsh — post-OMZ dotfiles config
# Sourced directly from ~/.zshrc (injected by the dotfiles installer).
# DOTFILE_PATH is exported in ~/.zshrc before this file is sourced.
#
# Third-party tools (nvm, conda, etc.) append their config after this block
# in ~/.zshrc — they never touch this file.

# PATH: prioritize Homebrew ARM, fallback to Intel if needed
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH"

# ---- Homebrew ARM (default) ----
if [[ "$(uname -m)" == "arm64" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Optional: ensures we are always calling ARM brew (only if present)
if [[ -x /opt/homebrew/bin/brew ]]; then
  alias brew="/opt/homebrew/bin/brew"
  alias upbrew="/opt/homebrew/bin/brew upgrade && /opt/homebrew/bin/brew upgrade --cask --greedy --verbose"
fi


# Initialize asdf (if installed via Homebrew)
if command -v asdf >/dev/null 2>&1; then
  . "$(brew --prefix asdf)"/libexec/asdf.sh
  [[ -r ~/.asdf/plugins/java/set-java-home.zsh ]] && . ~/.asdf/plugins/java/set-java-home.zsh
fi

# Shared aliases
[[ -r $DOTFILE_PATH/config/zsh/zsh_aliases.zsh ]] && source $DOTFILE_PATH/config/zsh/zsh_aliases.zsh


# Personal overrides — edit ~/.zsh_custom.zsh freely, it is never overwritten
[[ -r $HOME/.zsh_custom.zsh ]] && source $HOME/.zsh_custom.zsh

# Powerlevel10k config — must be sourced after OMZ
[[ -r $HOME/.p10k.zsh ]] && source $HOME/.p10k.zsh
