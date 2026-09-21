# zsh_postload.zsh — post-OMZ dotfiles config
# Sourced directly from ~/.zshrc (injected by the dotfiles installer).
# DOTFILE_PATH is exported in ~/.zshrc before this file is sourced.
#
# Third-party tools (nvm, conda, etc.) append their config after this block
# in ~/.zshrc — they never touch this file.

# PATH: prioritize Homebrew ARM, fallback to Intel if needed
# Guarded to avoid re-prepending on repeated sourcing (nested shells), which would
# otherwise push asdf shims (added below) behind Homebrew and break version pinning.
case ":$PATH:" in
  *":/opt/homebrew/bin:"*) ;;
  *) export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH" ;;
esac

# ---- Homebrew ARM (default) ----
if [[ "$(uname -m)" == "arm64" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Optional: ensures we are always calling ARM brew (only if present)
if [[ -x /opt/homebrew/bin/brew ]]; then
  alias brew="/opt/homebrew/bin/brew"
  alias upbrew="/opt/homebrew/bin/brew upgrade && /opt/homebrew/bin/brew upgrade --cask --greedy --verbose"
fi


# pnpm setup for global install
export PNPM_HOME="$HOME/Library/pnpm"
[[ -d "$PNPM_HOME" ]] || mkdir -p "$PNPM_HOME"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Initialize asdf (if installed via Homebrew, v0.14+ Go rewrite — no asdf.sh)
# Must win over Homebrew so pinned tool-versions take priority over `brew`-installed
# runtimes (e.g. node). `brew shellenv` above re-prepends /opt/homebrew/bin on every
# sourcing with no guard, so we can't just skip-if-present here — that would leave
# the shims stranded behind Homebrew once re-sourced (e.g. nested/VS Code shells).
# Instead, strip any existing occurrence of the shims dir and re-prepend it fresh,
# guaranteeing it is always first regardless of how many times this file is sourced.
if command -v asdf >/dev/null 2>&1; then
  ASDF_SHIMS_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
  path=("$ASDF_SHIMS_DIR" "${path[@]:#$ASDF_SHIMS_DIR}")
  unset ASDF_SHIMS_DIR
  fpath=("$(brew --prefix asdf)/share/zsh/site-functions" $fpath)
  [[ -r ~/.asdf/plugins/java/set-java-home.zsh ]] && . ~/.asdf/plugins/java/set-java-home.zsh
fi

# Shared aliases
[[ -r $DOTFILE_PATH/config/zsh/zsh_aliases.zsh ]] && source $DOTFILE_PATH/config/zsh/zsh_aliases.zsh

# Forgejo / Colima helpers
[[ -r $DOTFILE_PATH/config/zsh/zsh_forgejo.zsh ]] && source $DOTFILE_PATH/config/zsh/zsh_forgejo.zsh


# Personal overrides — edit ~/.zsh_custom.zsh freely, it is never overwritten
[[ -r $HOME/.zsh_custom.zsh ]] && source $HOME/.zsh_custom.zsh

# Powerlevel10k config — must be sourced after OMZ
[[ -r $HOME/.p10k.zsh ]] && source $HOME/.p10k.zsh

# Disable automatic correction (suggestions still work, but no more "zsh: correct 'gti' to 'git' [nyae]?")
unsetopt correct
unsetopt correct_all