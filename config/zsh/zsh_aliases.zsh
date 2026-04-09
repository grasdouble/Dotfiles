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
alias fshow='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias fhide='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
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
alias lll='echo "brewcask, setCalibreTmp, ttop, fshow, fhide, cleanupDS, kdock, addDockSeparator, zipFolders, gpb/git-clean-branches (clean git branches), gbvv (list branch with link to origin), dockerStart (start colima + portainer), dockerStop (stop colima), dockerUpdate (backup + update portainer), dockerUi (open portainer ui) — see zsh_forgejo.zsh for forgejoStart/Stop/Update/Ui/Sync/BackfillCommits"'

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
  [[ -n "$gone_branches" ]] && echo "$gone_branches" | xargs git branch -D
}
alias git-clean-branches='git_clean_branches'

# docker ui with colima and portainer

dockerStart() {
  colima start

  # If container already exists, just start it instead of creating a new one
  if docker inspect portainer &>/dev/null; then
    echo "Container 'portainer' already exists. Starting it..."
    docker start portainer
    return
  fi

  docker run -d \
    --name portainer \
    --restart=always \
    -p 9443:9443 \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:lts
}

dockerUpdate() {
  # 1. Check Colima is running
  if ! colima status &>/dev/null; then
    echo "ERROR: Colima is not running. Run 'dockerStart' first."
    return 1
  fi

  # 2. Check if a new version is available
  echo "Checking for a new version..."
  local local_digest
  local_digest=$(docker inspect --format='{{index .RepoDigests 0}}' \
    portainer/portainer-ce:lts 2>/dev/null | cut -d'@' -f2)
  local remote_digest
  remote_digest=$(docker buildx imagetools inspect \
    portainer/portainer-ce:lts --format '{{json .Manifest}}' \
    2>/dev/null | grep -m1 '"digest"' | awk -F'"' '{print $4}')

  if [[ -z "$remote_digest" ]]; then
    echo "ERROR: Could not fetch remote digest (network issue or buildx not available). Aborting."
    return 1
  fi
  if [[ -n "$local_digest" && "$remote_digest" == "$local_digest" ]]; then
    echo "Portainer is already up to date. No update needed."
    return 0
  fi
  echo "New version available."

  # 3. Ask for backup path
  local default_backup="/Volumes/Luffy/Dockers/Backups/Portainer"
  echo -n "Backup path [$default_backup]: "
  read -r user_backup_path
  local backup_root="${user_backup_path:-$default_backup}"
  local backup_dir="$backup_root/$(date +%Y%m%d_%H%M%S)"

  # 4. Archive portainer_data volume
  echo "Backing up portainer_data volume -> $backup_dir"
  mkdir -p "$backup_dir"
  docker rm -f portainer_backup_tmp &>/dev/null
  docker run --name portainer_backup_tmp \
    -v portainer_data:/data \
    alpine tar czf /portainer_data.tar.gz -C /data .
  docker cp portainer_backup_tmp:/portainer_data.tar.gz "$backup_dir/portainer_data.tar.gz"
  docker rm portainer_backup_tmp

  # 5. Verify backup succeeded
  if [[ ! -f "$backup_dir/portainer_data.tar.gz" ]]; then
    echo "ERROR: backup failed. Update cancelled."
    return 1
  fi

  # 6. stop → rm → pull → run
  echo "Stopping and removing old container..."
  docker rm -f portainer

  echo "Pulling new image..."
  docker pull portainer/portainer-ce:lts

  echo "Restarting Portainer..."
  docker run -d \
    --name portainer \
    --restart=always \
    -p 9443:9443 \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:lts

  # 7. Done
  echo "Update complete. Backup available at: $backup_dir"
}

alias dockerStop='colima stop'
alias dockerUi='open http://localhost:9000'

