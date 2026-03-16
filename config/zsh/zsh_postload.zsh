# zsh_postload.zsh — post-OMZ dotfiles config
# Symlinked to ~/.zsh_postload.zsh by the dotfiles installer.
# Injected into ~/.zshrc just after `source $ZSH/oh-my-zsh.sh`.
#
# Third-party tools (nvm, conda, etc.) append their config after this block
# in ~/.zshrc — they never touch this file.

# Dotfile path bootstrap
[[ -r $HOME/.dotfiles-config-path.zsh ]] && source $HOME/.dotfiles-config-path.zsh

# p10k prompt + shared aliases
[[ -r $DOTFILE_PATH/zsh/p10k.zsh ]] && source $DOTFILE_PATH/zsh/p10k.zsh
[[ -r $DOTFILE_PATH/zsh/aliases.zsh ]] && source $DOTFILE_PATH/zsh/aliases.zsh

export ASDF_NPM_DEFAULT_PACKAGES_FILE=${DOTFILE_PATH}/asdf/default-npm-package

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

# For opencode vscode extension
export EDITOR="code --wait"

# For crossover script
pidof() { pgrep -x "$@"; }

# Initialize asdf (if installed via Homebrew)
if command -v asdf >/dev/null 2>&1; then
  . "$(brew --prefix asdf)"/libexec/asdf.sh
  [[ -r ~/.asdf/plugins/java/set-java-home.zsh ]] && . ~/.asdf/plugins/java/set-java-home.zsh
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:${HOME}/.cache/lm-studio/bin"
# End of LM Studio CLI section

# GITHUB FAST ACCESS
git_clean_branches() {
  git fetch --all --prune --prune-tags

  # Remote wins for the tags: we force the update of the tags from each remote
  for r in $(git remote); do
    git remote prune "$r"
    git fetch "$r" --tags --force --prune --prune-tags
  done

  git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
    | awk '$2=="[gone]"{print $1}' \
    | xargs -r git branch -D
}

alias git-clean-branches='git_clean_branches'

# opencode
export PATH=${HOME}/.opencode/bin:$PATH

# Added by Antigravity
export PATH="${HOME}/.antigravity/antigravity/bin:$PATH"

# For BMAD with codex
alias codex='CODEX_HOME="$PWD/.codex" codex'

# docker ui with colima and portainer
alias dockerStart='colima start && docker run -d -p 9443:9443 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce'
alias dockerStop='colima stop'
alias dockerUi='open http://localhost:9000'

# Personal overrides — edit ~/.zsh_custom.zsh freely, it is never overwritten
[[ -r $HOME/.zsh_custom.zsh ]] && source $HOME/.zsh_custom.zsh
