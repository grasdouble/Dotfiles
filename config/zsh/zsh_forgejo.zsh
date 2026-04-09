# zsh_forgejo.zsh — Forgejo + Colima helpers
# Sourced from zsh_postload.zsh via DOTFILE_PATH.
#
# Required env vars:
#   GITHUB_TOKEN   — GitHub personal access token
#   FORGEJO_TOKEN  — Forgejo personal access token
#   FORGEJO_URL    — e.g. http://localhost:3000
#
# Public commands:
#   forgejoStart              start Colima + Forgejo container
#   forgejoStop               stop Forgejo container
#   forgejoUpdate             backup + update Forgejo image
#   forgejoUi                 open Forgejo in browser
#   forgejoSync [--dry-run]   mirror GitHub repos → Forgejo
#   forgejoBackfillCommits [--dry-run]
#                             backfill contribution graph from GitHub commits

# ────────────────────────────────────────────────────────────────────────────
# Low-level helpers
# ────────────────────────────────────────────────────────────────────────────

# Forgejo API curl: _forgejo_curl <METHOD> <path> [extra curl args...]
_forgejo_curl() {
  local method="$1" path="$2"; shift 2
  curl -sf -X "$method" \
    -H "Authorization: token $FORGEJO_TOKEN" \
    -H "Content-Type: application/json" \
    "$FORGEJO_URL$path" "$@"
}

# GitHub API curl: _forgejo_gh_curl <path> [extra curl args...]
_forgejo_gh_curl() {
  local path="$1"; shift
  curl -sf \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com$path" "$@"
}

# Validates Colima is running and all required env vars are set.
_forgejo_check_env() {
  if ! colima status &>/dev/null; then
    echo "ERROR: Colima is not running. Run 'forgejoStart' first."
    return 1
  fi
  local missing=()
  [[ -z "$GITHUB_TOKEN" ]]  && missing+=("GITHUB_TOKEN")
  [[ -z "$FORGEJO_TOKEN" ]] && missing+=("FORGEJO_TOKEN")
  [[ -z "$FORGEJO_URL" ]]   && missing+=("FORGEJO_URL")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required env var(s): ${missing[*]}"
    echo "       Set them in your shell environment before calling this command."
    return 1
  fi
}

# Prints forgejoSync result summary using shared _fjs_ counters/lists.
_forgejo_print_summary() {
  echo ""
  echo "────────────────────────────────────────"
  echo "Sync complete — created: $_fjs_created  updated: $_fjs_updated  skipped: $_fjs_skipped  errors: $_fjs_errors"
  echo "             releases: +$_fjs_releases_created created, $_fjs_releases_skipped already up to date"
  echo ""
  if [[ ${#_fjs_created_list[@]} -gt 0 ]]; then
    echo "Created (${#_fjs_created_list[@]}):"
    for r in "${_fjs_created_list[@]}"; do echo "  + $r"; done
    echo ""
  fi
  if [[ ${#_fjs_updated_list[@]} -gt 0 ]]; then
    echo "Updated visibility (${#_fjs_updated_list[@]}):"
    for r in "${_fjs_updated_list[@]}"; do echo "  ~ $r"; done
    echo ""
  fi
  if [[ ${#_fjs_skipped_list[@]} -gt 0 ]]; then
    echo "Skipped / already up to date (${#_fjs_skipped_list[@]}):"
    for r in "${_fjs_skipped_list[@]}"; do echo "  = $r"; done
    echo ""
  fi
  if [[ ${#_fjs_error_list[@]} -gt 0 ]]; then
    echo "Errors (${#_fjs_error_list[@]}):"
    for r in "${_fjs_error_list[@]}"; do echo "  ! $r"; done
    echo ""
  fi
  echo "────────────────────────────────────────"
}

# Paginates GitHub repos. Path template must contain PAGE.
# Outputs: clone_url|repo_name|private
_forgejo_paginate_gh_repos() {
  local path_tpl="$1" page=1 chunk
  while true; do
    chunk=$(_forgejo_gh_curl "${path_tpl/PAGE/$page}" \
      | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    print(r['clone_url'] + '|' + r['name'] + '|' + str(r['private']).lower())
" 2>/dev/null)
    [[ -z "$chunk" ]] && break
    echo "$chunk"
    (( page++ ))
  done
}

# Paginates all Forgejo mirror repos.
# Outputs: repo_id|owner_login|repo_name|private
_forgejo_paginate_mirror_repos() {
  local page=1 chunk
  while true; do
    chunk=$(_forgejo_curl GET "/api/v1/repos/search?limit=50&page=$page" \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)
repos = data.get('data', data) if isinstance(data, dict) else data
for r in repos:
    if r.get('mirror'):
        print(str(r['id']) + '|' + r['owner']['login'] + '|' + r['name'] + '|' + str(r['private']).lower())
" 2>/dev/null)
    [[ -z "$chunk" ]] && break
    echo "$chunk"
    (( page++ ))
  done
}

# ────────────────────────────────────────────────────────────────────────────
# Internal helpers: bind mount check, migrate payload
# ────────────────────────────────────────────────────────────────────────────

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

# Calls POST /repos/migrate; outputs HTTP status code.
_forgejo_run_migrate() {
  local clone_url="$1" repo_name="$2" owner="$3" private="$4"
  _forgejo_curl POST /api/v1/repos/migrate \
    -o /dev/null -w "%{http_code}" \
    -d "{
      \"clone_addr\": \"$clone_url\",
      \"repo_name\": \"$repo_name\",
      \"repo_owner\": \"$owner\",
      \"mirror\": true,
      \"mirror_interval\": \"8h0m0s\",
      \"private\": $private,
      \"auth_token\": \"$GITHUB_TOKEN\"
    }"
}

# ────────────────────────────────────────────────────────────────────────────
# forgejoStart — start Colima then start (or create) the Forgejo container
# ────────────────────────────────────────────────────────────────────────────
forgejoStart() {
  colima start
  _check_dockers_mount || return 1
  if docker inspect forgejo &>/dev/null; then
    echo "Container 'forgejo' already exists. Starting it..."
    docker start forgejo
    return
  fi
  docker run -d --name forgejo --restart=always \
    -e USER_UID=1000 -e USER_GID=1000 \
    -p 3000:3000 -p 222:22 \
    -v /Volumes/Luffy/Dockers/Data/Forgejo:/data \
    codeberg.org/forgejo/forgejo:14
}

# ────────────────────────────────────────────────────────────────────────────
# forgejoUpdate — backup data dir then pull + restart Forgejo
# ────────────────────────────────────────────────────────────────────────────
forgejoUpdate() {
  if ! colima status &>/dev/null; then
    echo "ERROR: Colima is not running. Run 'forgejoStart' first."
    return 1
  fi
  _check_dockers_mount || return 1

  echo "Checking for a new version..."
  local local_digest remote_digest
  local_digest=$(docker inspect --format='{{index .RepoDigests 0}}' \
    codeberg.org/forgejo/forgejo:14 2>/dev/null | cut -d'@' -f2)
  remote_digest=$(docker buildx imagetools inspect \
    codeberg.org/forgejo/forgejo:14 --format '{{json .Manifest}}' \
    2>/dev/null | grep -m1 '"digest"' | awk -F'"' '{print $4}')
  if [[ -z "$remote_digest" ]]; then
    echo "ERROR: Could not fetch remote digest (network issue or buildx not available). Aborting."
    return 1
  fi
  if [[ -n "$local_digest" && "$remote_digest" == "$local_digest" ]]; then
    echo "Forgejo is already up to date. No update needed."
    return 0
  fi
  echo "New version available."

  local local_major remote_major
  local_major=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' \
    codeberg.org/forgejo/forgejo:14 2>/dev/null | cut -d'.' -f1)
  remote_major=$(docker buildx imagetools inspect \
    codeberg.org/forgejo/forgejo:14 --format '{{json .}}' \
    2>/dev/null | grep -o '"org.opencontainers.image.version":"[^"]*"' \
    | head -1 | awk -F'"' '{print $4}' | cut -d'.' -f1)
  if [[ -n "$local_major" && -n "$remote_major" && "$local_major" != "$remote_major" ]]; then
    echo "WARNING: This is a MAJOR version upgrade ($local_major -> $remote_major)."
    echo "Forgejo requires manual verification for major upgrades. See: https://forgejo.org/docs/latest/admin/upgrade/"
    echo -n "Are you sure you want to continue? [y/N]: "
    read -r confirm
    [[ "${confirm:l}" != "y" ]] && echo "Update cancelled." && return 0
  fi

  local default_backup="/Volumes/Luffy/Dockers/Backups/Forgejo"
  echo -n "Backup path [$default_backup]: "
  read -r user_backup_path
  local backup_dir="${user_backup_path:-$default_backup}/$(date +%Y%m%d_%H%M%S)"
  echo "Backing up Forgejo data -> $backup_dir"
  mkdir -p "$backup_dir"
  if ! cp -r /Volumes/Luffy/Dockers/Data/Forgejo "$backup_dir/forgejo_data"; then
    echo "ERROR: backup failed. Update cancelled."
    return 1
  fi
  if [[ ! -d "$backup_dir/forgejo_data" ]]; then
    echo "ERROR: backup directory missing after copy. Update cancelled."
    return 1
  fi

  echo "Stopping and removing old container..."
  docker rm -f forgejo
  echo "Pulling new image..."
  docker pull codeberg.org/forgejo/forgejo:14
  echo "Restarting Forgejo..."
  docker run -d --name forgejo --restart=always \
    -e USER_UID=1000 -e USER_GID=1000 \
    -p 3000:3000 -p 222:22 \
    -v /Volumes/Luffy/Dockers/Data/Forgejo:/data \
    codeberg.org/forgejo/forgejo:14
  echo "Update complete. Backup available at: $backup_dir"
}

alias forgejoStop='docker stop forgejo'
alias forgejoUi='open http://localhost:3000'

# ────────────────────────────────────────────────────────────────────────────
# _forgejo_migrate_repo <clone_url> <repo_name> <forgejo_owner> <private: true|false>
# ────────────────────────────────────────────────────────────────────────────
_forgejo_migrate_repo() {
  local clone_url="$1" repo_name="$2" owner="$3" private="${4:-false}"
  local gh_owner
  gh_owner=$(echo "$clone_url" | awk -F'/' '{print $(NF-1)}')
  echo -n "."

  local http_code
  http_code=$(_forgejo_run_migrate "$clone_url" "$repo_name" "$owner" "$private")

  case "$http_code" in
    201) (( _fjs_created++ )) ; _fjs_created_list+=("$owner/$repo_name") ;;
    409)
      local get_code get_body
      get_body=$(_forgejo_curl GET "/api/v1/repos/$owner/$repo_name" -w "\n%{http_code}" 2>/dev/null)
      get_code="${get_body##*$'\n'}"
      get_body="${get_body%$'\n'*}"

      if [[ "$get_code" == "404" ]]; then
        # Orphan git dir left after manual deletion — remove and retry once.
        docker exec forgejo rm -rf \
          "/data/git/repositories/$owner/$(echo "$repo_name" | tr '[:upper:]' '[:lower:]').git" 2>/dev/null
        local retry_code
        retry_code=$(_forgejo_run_migrate "$clone_url" "$repo_name" "$owner" "$private")
        if [[ "$retry_code" == "201" ]]; then
          (( _fjs_created++ )) ; _fjs_created_list+=("$owner/$repo_name (orphan cleaned)")
        else
          (( _fjs_errors++ ))
          _fjs_error_list+=("$owner/$repo_name (orphan cleanup attempted, retry HTTP $retry_code)")
        fi
        return
      fi

      if [[ "$get_code" != "200" ]]; then
        (( _fjs_errors++ ))
        _fjs_error_list+=("$owner/$repo_name (migrate conflict but repo not accessible: GET $get_code)")
        return
      fi

      local current_private
      current_private=$(echo "$get_body" \
        | python3 -c "import sys,json; print(str(json.load(sys.stdin)['private']).lower())" 2>/dev/null)
      if [[ "$current_private" != "$private" ]]; then
        local patch_code
        patch_code=$(_forgejo_curl PATCH "/api/v1/repos/$owner/$repo_name" \
          -o /dev/null -w "%{http_code}" -d "{\"private\": $private}")
        if [[ "$patch_code" == "200" ]]; then
          (( _fjs_updated++ )) ; _fjs_updated_list+=("$owner/$repo_name ($current_private -> $private)")
        else
          (( _fjs_errors++ )) ; _fjs_error_list+=("$owner/$repo_name (visibility update HTTP $patch_code)")
        fi
      else
        (( _fjs_skipped++ )) ; _fjs_skipped_list+=("$owner/$repo_name")
      fi
      ;;
    *) (( _fjs_errors++ )) ; _fjs_error_list+=("$owner/$repo_name (HTTP $http_code)") ; return ;;
  esac

  _forgejo_sync_releases "$gh_owner" "$repo_name" "$owner"
}

# ────────────────────────────────────────────────────────────────────────────
# _forgejo_sync_releases <gh_owner> <repo_name> <forgejo_owner>
# Syncs GitHub releases → Forgejo, backdating created_unix in SQLite.
# ────────────────────────────────────────────────────────────────────────────
_forgejo_sync_releases() {
  local gh_owner="$1" repo_name="$2" forgejo_owner="$3"
  local db="/Volumes/Luffy/Dockers/Data/Forgejo/gitea/gitea.db"

  local forgejo_repo_id
  forgejo_repo_id=$(_forgejo_curl GET "/api/v1/repos/$forgejo_owner/$repo_name" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

  local latest_forgejo_ts
  latest_forgejo_ts=$(_forgejo_curl GET "/api/v1/repos/$forgejo_owner/$repo_name/releases?limit=1&page=1" \
    | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
if data:
    pub = data[0].get('published_at') or data[0].get('created_at') or ''
    try: print(int(datetime.fromisoformat(pub.replace('Z','+00:00')).timestamp()))
    except: print(0)
else: print(0)
" 2>/dev/null)
  latest_forgejo_ts="${latest_forgejo_ts:-0}"

  local page=1 _done=0 _raw_releases _rel_http
  while [[ $_done -eq 0 ]]; do
    _raw_releases=$(_forgejo_gh_curl "/repos/$gh_owner/$repo_name/releases?per_page=100&page=$page" \
      | python3 -c "
import sys, json
from datetime import datetime
for r in json.load(sys.stdin):
    name = (r.get('name') or r['tag_name']).replace('|','')
    body = (r.get('body') or '').replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', '\\\\n').replace('\r', '')
    pub = r.get('published_at') or r.get('created_at') or ''
    try: ts = int(datetime.fromisoformat(pub.replace('Z','+00:00')).timestamp())
    except: ts = 0
    print(r['tag_name'] + '|' + name + '|' + str(r['draft']).lower() + '|' + str(r['prerelease']).lower() + '|' + str(ts) + '|' + body)
" 2>/dev/null)
    [[ -z "$_raw_releases" ]] && break

    while IFS='|' read -r tag_name release_name is_draft is_prerelease published_ts body; do
      if [[ "$published_ts" -le "$latest_forgejo_ts" ]]; then _done=1; break; fi
      _rel_http=$(_forgejo_curl POST "/api/v1/repos/$forgejo_owner/$repo_name/releases" \
        -o /dev/null -w "%{http_code}" \
        -d "{\"tag_name\":\"$tag_name\",\"name\":\"$release_name\",\"body\":\"$body\",\"draft\":$is_draft,\"prerelease\":$is_prerelease}")
      if [[ "$_rel_http" == "201" ]]; then
        (( _fjs_releases_created++ ))
        if [[ -n "$forgejo_repo_id" && "$published_ts" -gt 0 && -f "$db" ]]; then
          sqlite3 "$db" \
            "UPDATE release SET created_unix=$published_ts WHERE repo_id=$forgejo_repo_id AND tag_name='${tag_name//\'/\'\'}';
             UPDATE action SET created_unix=$published_ts WHERE op_type=24 AND repo_id=$forgejo_repo_id AND ref_name='${tag_name//\'/\'\'}';" \
            2>/dev/null
        fi
      elif [[ "$_rel_http" == "409" ]]; then
        (( _fjs_releases_skipped++ ))
      else
        (( _fjs_errors++ )) ; _fjs_error_list+=("$forgejo_owner/$repo_name release $tag_name (HTTP $_rel_http)")
      fi
    done <<< "$_raw_releases"
    (( page++ ))
  done
}

# ────────────────────────────────────────────────────────────────────────────
# forgejoSync [--dry-run] — mirror all GitHub repos to Forgejo
# ────────────────────────────────────────────────────────────────────────────
forgejoSync() {
  local dry_run=0
  [[ "$1" == "--dry-run" ]] && dry_run=1

  _forgejo_check_env || return 1

  local forgejo_user
  forgejo_user=$(_forgejo_curl GET /api/v1/user \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])" 2>/dev/null)
  if [[ -z "$forgejo_user" ]]; then
    echo "ERROR: Could not retrieve Forgejo user. Check FORGEJO_URL and FORGEJO_TOKEN."
    return 1
  fi
  echo "Forgejo user: $forgejo_user"

  local org_status
  org_status=$(_forgejo_curl GET /api/v1/orgs/grasdouble -o /dev/null -w "%{http_code}")
  if [[ "$org_status" == "000" ]]; then
    echo "ERROR: Could not reach Forgejo (connection failed)."
    return 1
  elif [[ "$org_status" == "404" ]]; then
    echo "Org 'grasdouble' not found in Forgejo — creating it..."
    if [[ $dry_run -eq 0 ]]; then
      _forgejo_curl POST /api/v1/orgs -d '{"username":"grasdouble","visibility":"private"}' >/dev/null
      echo "Org 'grasdouble' created."
    else
      echo "[dry-run] Would create org 'grasdouble'."
    fi
  else
    echo "Org 'grasdouble' already exists in Forgejo."
  fi

  local _fjs_created=0 _fjs_skipped=0 _fjs_updated=0 _fjs_errors=0
  local _fjs_releases_created=0 _fjs_releases_skipped=0
  local _fjs_skipped_list=() _fjs_created_list=() _fjs_updated_list=() _fjs_error_list=()

  echo ""
  echo -n "Syncing personal repos (noofreuuuh)... "
  while IFS='|' read -r clone_url repo_name repo_private; do
    if [[ $dry_run -eq 1 ]]; then
      echo "[dry-run] Would mirror: $clone_url -> $forgejo_user/$repo_name (private: $repo_private)"
    else
      _forgejo_migrate_repo "$clone_url" "$repo_name" "$forgejo_user" "$repo_private"
    fi
  done < <(_forgejo_paginate_gh_repos "/user/repos?affiliation=owner&per_page=100&page=PAGE")
  echo ""

  echo -n "Syncing org repos (grasdouble)... "
  while IFS='|' read -r clone_url repo_name repo_private; do
    if [[ $dry_run -eq 1 ]]; then
      echo "[dry-run] Would mirror: $clone_url -> grasdouble/$repo_name (private: $repo_private)"
    else
      _forgejo_migrate_repo "$clone_url" "$repo_name" "grasdouble" "$repo_private"
    fi
  done < <(_forgejo_paginate_gh_repos "/orgs/grasdouble/repos?per_page=100&page=PAGE")
  echo ""

  if [[ $dry_run -eq 1 ]]; then
    echo ""
    echo "────────────────────────────────────────"
    echo "Dry-run complete. No changes made."
    echo "────────────────────────────────────────"
    return 0
  fi
  _forgejo_print_summary
}

# ────────────────────────────────────────────────────────────────────────────
# forgejoBackfillCommits [--dry-run]
# Inserts action rows (op_type=18) for GitHub commits not yet in Forgejo.
# Stops Forgejo before writing SQLite, restarts after (trap on EXIT/INT/TERM).
# ────────────────────────────────────────────────────────────────────────────
forgejoBackfillCommits() {
  local dry_run=0
  [[ "$1" == "--dry-run" ]] && dry_run=1

  local db="/Volumes/Luffy/Dockers/Data/Forgejo/gitea/gitea.db"
  _forgejo_check_env || return 1
  [[ ! -f "$db" ]] && echo "ERROR: Forgejo DB not found at $db" && return 1

  # Resolve Forgejo user — before stopping the container
  local forgejo_user_id forgejo_user_login forgejo_user_email
  IFS='|' read -r forgejo_user_id forgejo_user_login forgejo_user_email < <(
    _forgejo_curl GET /api/v1/user \
      | python3 -c "
import sys,json
u=json.load(sys.stdin)
print(str(u['id'])+'|'+u['login']+'|'+u['email'])
" 2>/dev/null)
  if [[ -z "$forgejo_user_id" || -z "$forgejo_user_email" ]]; then
    echo "ERROR: Could not retrieve Forgejo user info. Check FORGEJO_URL and FORGEJO_TOKEN."
    return 1
  fi
  echo "Forgejo user: $forgejo_user_login (id=$forgejo_user_id, email=$forgejo_user_email)"

  # Resolve GitHub login — before stopping the container
  local gh_user_login
  gh_user_login=$(_forgejo_gh_curl /user \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])" 2>/dev/null)
  if [[ -z "$gh_user_login" ]]; then
    echo "ERROR: Could not retrieve GitHub user login. Check GITHUB_TOKEN."
    return 1
  fi
  echo "GitHub user: $gh_user_login"

  # List all mirror repos — before stopping the container
  local all_repos
  all_repos=$(_forgejo_paginate_mirror_repos)
  if [[ -z "$all_repos" ]]; then
    echo "No mirror repos found in Forgejo. Run forgejoSync first."
    return 0
  fi

  # Stop Forgejo to avoid concurrent SQLite writes; restart on any exit.
  local forgejo_was_running=0
  if docker inspect forgejo &>/dev/null && \
     [[ "$(docker inspect -f '{{.State.Running}}' forgejo 2>/dev/null)" == "true" ]]; then
    forgejo_was_running=1
  fi
  if [[ $dry_run -eq 0 && $forgejo_was_running -eq 1 ]]; then
    echo "Stopping Forgejo to safely write to SQLite DB..."
    docker stop forgejo &>/dev/null
    trap 'docker start forgejo &>/dev/null; trap - EXIT INT TERM' EXIT INT TERM
  fi

  local _bf_inserted=0 _bf_skipped_exists=0 _bf_repos=0
  local -A _bf_owner_ids _bf_orig_urls
  while IFS='|' read -r _rid _oid _ourl; do
    _bf_owner_ids[$_rid]=$_oid
    _bf_orig_urls[$_rid]=$_ourl
  done < <(sqlite3 "$db" "SELECT id, owner_id, original_url FROM repository WHERE is_mirror=1;" 2>/dev/null)

  while IFS='|' read -r forgejo_repo_id forgejo_owner forgejo_repo_name is_private; do
    [[ -z "$forgejo_repo_id" ]] && continue
    (( _bf_repos++ ))
    echo -n "[$forgejo_owner/$forgejo_repo_name] "

    local mirror_address="${_bf_orig_urls[$forgejo_repo_id]}"
    local gh_owner gh_repo
    gh_owner=$(echo "$mirror_address" | awk -F'/' '{print $(NF-1)}')
    gh_repo=$(echo "$mirror_address" | awk -F'/' '{print $NF}' | sed 's/\.git$//')
    if [[ -z "$gh_owner" || -z "$gh_repo" ]]; then
      echo "skipped (cannot resolve GitHub source)"
      continue
    fi

    local repo_owner_id="${_bf_owner_ids[$forgejo_repo_id]}"
    local is_private_int=0
    [[ "$is_private" == "true" ]] && is_private_int=1

    # Incremental since= : load max timestamp + known SHAs at boundary
    local latest_ts
    latest_ts=$(sqlite3 "$db" \
      "SELECT COALESCE(MAX(created_unix),0) FROM action
       WHERE op_type=18 AND repo_id=$forgejo_repo_id
         AND act_user_id=$forgejo_user_id AND user_id=$forgejo_user_id;" 2>/dev/null)
    latest_ts="${latest_ts:-0}"

    local since_param="" since_iso=""
    if [[ "$latest_ts" -gt 0 ]]; then
      since_iso=$(date -u -r "$latest_ts" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
      [[ -n "$since_iso" ]] && since_param="&since=$since_iso"
    fi

    local -A _repo_known_shas
    if [[ "$latest_ts" -gt 0 ]]; then
      local _s
      while IFS= read -r _s; do
        [[ -n "$_s" ]] && _repo_known_shas[$_s]=1
      done < <(sqlite3 "$db" \
        "SELECT json_extract(content,'$.HeadCommit.Sha1') FROM action
         WHERE op_type=18 AND repo_id=$forgejo_repo_id
           AND act_user_id=$forgejo_user_id AND created_unix>=$latest_ts;" 2>/dev/null)
    fi

    local branches
    branches=$(_forgejo_gh_curl "/repos/$gh_owner/$gh_repo/branches?per_page=100" \
      | python3 -c "import sys,json; [print(b['name']) for b in json.load(sys.stdin)]" 2>/dev/null)
    [[ -z "$branches" ]] && branches="main"

    local _repo_inserted=0 _inserts=""

    while IFS= read -r branch; do
      local commit_page=1
      while true; do
        local raw_commits
        raw_commits=$(_forgejo_gh_curl \
          "/repos/$gh_owner/$gh_repo/commits?sha=$branch&per_page=100&page=$commit_page&author=$gh_user_login${since_param}" \
          | python3 -c "
import sys, json
from datetime import datetime
for c in json.load(sys.stdin):
    com = c.get('commit') or {}
    ae = (com.get('author')    or {}).get('email','')
    an = (com.get('author')    or {}).get('name','')
    ce = (com.get('committer') or {}).get('email','')
    cn = (com.get('committer') or {}).get('name','')
    msg = (com.get('message') or '').split('\n')[0].replace('|','').replace(chr(39),'')
    ts_raw = (com.get('author') or {}).get('date','')
    try: ts = int(datetime.fromisoformat(ts_raw.replace('Z','+00:00')).timestamp())
    except: ts = 0
    print(c['sha']+'|'+ae+'|'+an+'|'+ce+'|'+cn+'|'+str(ts)+'|'+msg)
" 2>/dev/null)
        [[ -z "$raw_commits" ]] && break

        while IFS='|' read -r sha author_email author_name committer_email committer_name ts msg; do
          [[ -z "$sha" ]] && continue
          if [[ -n "${_repo_known_shas[$sha]}" ]]; then (( _bf_skipped_exists++ )); continue; fi

          if [[ $dry_run -eq 1 ]]; then
            echo ""
            echo "  [dry-run] Would insert action for commit $sha ($msg) ts=$ts branch=$branch"
            (( _bf_inserted++ )) ; _repo_known_shas[$sha]=1
            continue
          fi

          local safe_msg="${msg//\"/\\\"}"
          local compare_url="$forgejo_owner/$forgejo_repo_name/compare/$sha~1...$sha"
          local content_json="{\"Commits\":[{\"Sha1\":\"$sha\",\"Message\":\"$safe_msg\",\"AuthorEmail\":\"$author_email\",\"AuthorName\":\"$author_name\",\"CommitterEmail\":\"$committer_email\",\"CommitterName\":\"$committer_name\",\"Signature\":null,\"Verification\":null,\"Timestamp\":\"\"}],\"HeadCommit\":{\"Sha1\":\"$sha\",\"Message\":\"$safe_msg\",\"AuthorEmail\":\"$author_email\",\"AuthorName\":\"$author_name\",\"CommitterEmail\":\"$committer_email\",\"CommitterName\":\"$committer_name\",\"Signature\":null,\"Verification\":null,\"Timestamp\":\"\"},\"CompareURL\":\"$compare_url\",\"Len\":1}"
          local safe_content="${content_json//\'/\'\'}"
          _inserts+="
INSERT INTO action (user_id,op_type,act_user_id,repo_id,comment_id,ref_name,is_private,content,created_unix)
  VALUES ($repo_owner_id,18,$forgejo_user_id,$forgejo_repo_id,0,'refs/heads/$branch',$is_private_int,'$safe_content',$ts);
INSERT INTO action (user_id,op_type,act_user_id,repo_id,comment_id,ref_name,is_private,content,created_unix)
  VALUES ($forgejo_user_id,18,$forgejo_user_id,$forgejo_repo_id,0,'refs/heads/$branch',$is_private_int,'$safe_content',$ts);"
          _repo_known_shas[$sha]=1
          (( _bf_inserted++ )) ; (( _repo_inserted++ ))
        done <<< "$raw_commits"
        (( commit_page++ ))
      done
    done <<< "$branches"

    if [[ -n "$_inserts" && $dry_run -eq 0 ]]; then
      sqlite3 "$db" "BEGIN;${_inserts}
COMMIT;" 2>/dev/null
    fi

    if [[ -n "$since_param" ]]; then
      echo "done (incremental since ${since_iso}, +$_repo_inserted new commits)"
    else
      echo "done (full scan, +$_repo_inserted commits)"
    fi
  done <<< "$all_repos"

  echo ""
  echo "────────────────────────────────────────"
  if [[ $dry_run -eq 1 ]]; then
    echo "Dry-run complete — would insert: $_bf_inserted commit actions across $_bf_repos repos"
  else
    if [[ $_bf_inserted -gt 0 ]]; then
      echo "Rebuilding SQLite indexes..."
      sqlite3 "$db" "REINDEX action;" 2>/dev/null
    fi
    echo "Backfill complete — inserted: $_bf_inserted commit actions across $_bf_repos repos"
    echo "  skipped (already present): $_bf_skipped_exists"
    trap - EXIT INT TERM
    if [[ $forgejo_was_running -eq 1 ]]; then
      echo "Restarting Forgejo..."
      docker start forgejo &>/dev/null
    fi
  fi
  echo "────────────────────────────────────────"
}
