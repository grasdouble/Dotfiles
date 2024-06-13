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
alias lll='echo "brewcask, setCalibreTmp, ttop, fshow, fhide, cleanupDS, kdock, addDockSeparator, zipFolders"'

function git-prune-branches() {
        echo "switching to master or main branch.."
        git branch | grep 'main\|master' | xargs -n 1 git checkout
        echo "fetching with -p option...";
        git fetch -p;
        echo "running pruning of local branches"
        git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -d ;
}

alias gpb='git-prune-branches'