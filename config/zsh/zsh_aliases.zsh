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
alias lll='echo "brewcask, setCalibreTmp, ttop, fshow, fhide, cleanupDS, kdock, addDockSeparator, zipFolders, gpb/git-clean-branches (clean git branches), gbvv (list branch with link to origin), dockerStart (start colima + portainer), dockerStop (stop colima), dockerUpdate (backup + update portainer), dockerUi (open portainer ui), forgejoStart (start colima + forgejo), forgejoStop (stop forgejo), forgejoUpdate (backup + update forgejo), forgejoUi (open forgejo ui)"'

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

  git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
    | awk '$2=="[gone]"{print $1}' \
    | xargs -r git branch -D
}
alias git-clean-branches='git_clean_branches'

# docker ui with colima and portainer

# Check that /Volumes/Luffy/Dockers is properly mounted inside the Colima VM
_check_dockers_mount() {
  if ! docker run --rm -v /Volumes/Luffy/Dockers:/mnt alpine \
      test -d /mnt/Data &>/dev/null; then
    echo "ERROR: /Volumes/Luffy/Dockers is not accessible inside Colima."
    echo "       1. Make sure the 'Luffy' volume is mounted on macOS."
    echo "       2. Add the mount in ~/.colima/default/colima.yaml:"
    echo "            mounts:"
    echo "              - location: /Volumes/Luffy/Dockers"
    echo "                writable: true"
    echo "       3. Run: colima stop && colima start"
    return 1
  fi
}

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
  local local_digest=$(docker inspect --format='{{index .RepoDigests 0}}' \
    portainer/portainer-ce:lts 2>/dev/null | cut -d'@' -f2)
  local remote_digest=$(docker buildx imagetools inspect \
    portainer/portainer-ce:lts --format '{{json .Manifest}}' \
    2>/dev/null | grep -m1 '"digest"' | awk -F'"' '{print $4}')

  if [[ -n "$local_digest" && "$remote_digest" == "$local_digest" ]]; then
    echo "Portainer is already up to date. No update needed."
    return 0
  fi
  echo "New version available."

  # 3. Ask for backup path
  local default_backup="/Volumes/Luffy/Dockers/Backups/Portainer"
  echo -n "Backup path [$default_backup]: "
  read user_backup_path
  local backup_root="${user_backup_path:-$default_backup}"
  local backup_dir="$backup_root/$(date +%Y%m%d_%H%M%S)"

  # 4. Archive portainer_data volume
  echo "Backing up portainer_data volume -> $backup_dir"
  mkdir -p "$backup_dir"
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
  docker stop portainer && docker rm portainer

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

# forgejo with colima
forgejoStart() {
  colima start

  _check_dockers_mount || return 1

  # If container already exists, just start it instead of creating a new one
  if docker inspect forgejo &>/dev/null; then
    echo "Container 'forgejo' already exists. Starting it..."
    docker start forgejo
    return
  fi

  docker run -d \
    --name forgejo \
    --restart=always \
    -e USER_UID=1000 \
    -e USER_GID=1000 \
    -p 3000:3000 \
    -p 222:22 \
    -v /Volumes/Luffy/Dockers/Data/Forgejo:/data \
    codeberg.org/forgejo/forgejo:14
}

forgejoUpdate() {
  # 1. Check Colima is running
  if ! colima status &>/dev/null; then
    echo "ERROR: Colima is not running. Run 'forgejoStart' first."
    return 1
  fi

  # 2. Check bind mount is available
  _check_dockers_mount || return 1

  # 3. Check if a new version is available
  echo "Checking for a new version..."
  local local_digest=$(docker inspect --format='{{index .RepoDigests 0}}' \
    codeberg.org/forgejo/forgejo:14 2>/dev/null | cut -d'@' -f2)
  local remote_digest=$(docker buildx imagetools inspect \
    codeberg.org/forgejo/forgejo:14 --format '{{json .Manifest}}' \
    2>/dev/null | grep -m1 '"digest"' | awk -F'"' '{print $4}')

  if [[ -n "$local_digest" && "$remote_digest" == "$local_digest" ]]; then
    echo "Forgejo is already up to date. No update needed."
    return 0
  fi
  echo "New version available."

  # 4. Warn if a major version change is detected
  local local_major=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' \
    codeberg.org/forgejo/forgejo:14 2>/dev/null | cut -d'.' -f1)
  local remote_major=$(docker buildx imagetools inspect \
    codeberg.org/forgejo/forgejo:14 --format '{{json .}}' \
    2>/dev/null | grep -o '"org.opencontainers.image.version":"[^"]*"' \
    | head -1 | awk -F'"' '{print $4}' | cut -d'.' -f1)

  if [[ -n "$local_major" && -n "$remote_major" && "$local_major" != "$remote_major" ]]; then
    echo "WARNING: This is a MAJOR version upgrade ($local_major -> $remote_major)."
    echo "Forgejo requires manual verification for major upgrades. See: https://forgejo.org/docs/latest/admin/upgrade/"
    echo -n "Are you sure you want to continue? [y/N]: "
    read confirm
    if [[ "${confirm:l}" != "y" ]]; then
      echo "Update cancelled."
      return 0
    fi
  fi

  # 5. Ask for backup path
  local default_backup="/Volumes/Luffy/Dockers/Backups/Forgejo"
  echo -n "Backup path [$default_backup]: "
  read user_backup_path
  local backup_root="${user_backup_path:-$default_backup}"
  local backup_dir="$backup_root/$(date +%Y%m%d_%H%M%S)"

  # 6. Archive forgejo data directory
  echo "Backing up Forgejo data -> $backup_dir"
  mkdir -p "$backup_dir"
  cp -r /Volumes/Luffy/Dockers/Data/Forgejo "$backup_dir/forgejo_data"

  # 7. Verify backup succeeded
  if [[ ! -d "$backup_dir/forgejo_data" ]]; then
    echo "ERROR: backup failed. Update cancelled."
    return 1
  fi

  # 8. stop → rm → pull → run
  echo "Stopping and removing old container..."
  docker stop forgejo && docker rm forgejo

  echo "Pulling new image..."
  docker pull codeberg.org/forgejo/forgejo:14

  echo "Restarting Forgejo..."
  docker run -d \
    --name forgejo \
    --restart=always \
    -e USER_UID=1000 \
    -e USER_GID=1000 \
    -p 3000:3000 \
    -p 222:22 \
    -v /Volumes/Luffy/Dockers/Data/Forgejo:/data \
    codeberg.org/forgejo/forgejo:14

  # 9. Done
  echo "Update complete. Backup available at: $backup_dir"
}

alias forgejoStop='docker stop forgejo'
alias forgejoUi='open http://localhost:3000'