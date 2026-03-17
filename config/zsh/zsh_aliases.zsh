# ############################################################################
# ALIAS (COMMONS)
#   ------------------------------------------------------------
#   ttop:  Recommended 'top' invocation to minimize resources
#   ------------------------------------------------------------
alias ttop="top -R -F -s 10 -o rsize"
# ############################################################################
# ALIAS (MAC)
#   ------------------------------------------------------------
#   finderShowHidden:   Show hidden files in Finder
#   finderHideHidden:   Hide hidden files in Finder
#   ------------------------------------------------------------
alias fshow='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
alias fhide='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder /System/Library/CoreServices/Finder.app'
#   ------------------------------------------------------------
#   cleanupDS:  Recursively delete .DS_Store files
#   ------------------------------------------------------------
alias cleanupDS="find . -type f -name '*.DS_Store' -ls -delete"
#   ------------------------------------------------------------
#       Manage Dock
#   ------------------------------------------------------------
alias kdock='killall Dock'
alias addDockSeparator='defaults write com.apple.dock persistent-apps -array-add '\''{tile-type="small-spacer-tile";}'\'' && killall Dock'
# ############################################################################
alias ll='k -h'
# ############################################################################
# Fix python link for asdf
# alias python=/usr/bin/python3
# ############################################################################
alias brewcask='brew upgrade --cask --greedy --verbose'
alias zipFolders='for i in */; do zip -r "${i%/}.zip" "$i"; done'
alias setCalibreTmp='code ~/Library/Preferences/calibre/macos-env.txt'

# list of all aliases
alias lll='echo "brewcask, setCalibreTmp, ttop, fshow, fhide, cleanupDS, kdock, addDockSeparator, zipFolders, gpb/git-clean-branches (clean git branches), gbvv (list branch with link to origin)"'

alias gpb='git-clean-branches'
alias gbvv='git branch -vv'

# GITHUB FAST ACCESS
git_clean_branches() {
  git fetch --all --prune --prune-tags

  # Remote wins for the tags: we force the update of the tags from each remote
  for r in $(git remote); do
    git remote prune "$r"
    git fetch "$r" --tags --force --prune --prune-tags
  done

  local gone_branches
  gone_branches=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
    | awk '$2=="[gone]"{print $1}')
  if [[ -n "$gone_branches" ]]; then
    echo "$gone_branches" | xargs git branch -D
  fi
}
alias git-clean-branches='git_clean_branches'

# docker ui with colima and portainer
alias dockerStart='colima start && docker run -d -p 9443:9443 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce'
alias dockerStop='colima stop'
alias dockerUi='open http://localhost:9000'