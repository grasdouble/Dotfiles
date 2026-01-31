#!/bin/zsh
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
alias lll='echo "brewcask, setCalibreTmp, ttop, fshow, fhide, cleanupDS, kdock, addDockSeparator, zipFolders, gpb (clean git branches), gbvv (list branch with link to origin)"'

function git-prune-branches() {
    # Array to store the names of default branches
    default_branches=("develop" "main" "master")

    # Switch to an existing default branch
    for branch in "${default_branches[@]}"; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "Switching to $branch branch..."
            git checkout "$branch"
            break
        fi
    done

    echo "Fetching with -p option..."
    git fetch -p

    echo "Running pruning of local branches"
    while IFS= read -r branch; do
        if ! git branch -d "$branch" 2>/dev/null; then
            echo "The branch '$branch' is not fully merged."
            while true; do
                echo -n "Do you want to force delete it? (y/n) "
                read -r confirm
                case $confirm in
                    [Yy]* ) git branch -D "$branch"; break;;
                    [Nn]* ) echo "Skipping branch '$branch'"; break;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi
    done < <(git branch -vv | grep ': gone]' | grep -v "\*" | awk '{ print $1 }')
}

alias gpb='git-prune-branches'
alias gbvv='git branch -vv'