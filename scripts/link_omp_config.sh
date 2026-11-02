#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_config="${repo_root}/config/omp/config.yml"

if [[ ! -r "$repo_config" ]]; then
    printf '[ERROR] OMP config is missing or unreadable: %s\n' "$repo_config" >&2
    exit 1
fi
if ! command -v omp >/dev/null 2>&1; then
    printf '[ERROR] omp is required to locate its active config directory.\n' >&2
    exit 127
fi

if ! agent_dir="$(omp config path)" || [[ -z "$agent_dir" ]]; then
    printf '[ERROR] Could not resolve the active OMP config directory.\n' >&2
    exit 1
fi
config_path="${agent_dir%/}/config.yml"
legacy_path="${agent_dir%/}/config.yaml"

if [[ -L "$config_path" ]]; then
    if [[ "$config_path" -ef "$repo_config" ]]; then
        printf 'OMP config already linked to %s\n' "$repo_config"
        exit 0
    fi
    printf '[ERROR] Existing OMP config symlink points elsewhere; leaving it untouched: %s\n' "$config_path" >&2
    exit 1
fi

if [[ -e "$legacy_path" || -L "$legacy_path" ]]; then
    printf '[ERROR] Legacy OMP config exists; merge it into %s before linking: %s\n' "$repo_config" "$legacy_path" >&2
    exit 1
fi

if [[ -f "$config_path" ]]; then
    # Command substitution strips trailing newlines; they do not change YAML content.
    if [[ "$(<"$config_path")" != "$(<"$repo_config")" ]]; then
        printf '[ERROR] Existing OMP config differs from the repository; leaving it untouched.\n' >&2
        printf 'Merge its settings into %s, then move %s aside and rerun this script.\n' "$repo_config" "$config_path" >&2
        exit 1
    fi
    backup_path="${config_path}.pre-dotfiles.$(date +%Y%m%d%H%M%S).$$"
    if ! mv "$config_path" "$backup_path"; then
        printf '[ERROR] Could not preserve existing OMP config at %s\n' "$backup_path" >&2
        exit 1
    fi
    if ln -s "$repo_config" "$config_path"; then
        printf 'Linked OMP config to %s (previous file preserved at %s)\n' "$repo_config" "$backup_path"
        exit 0
    fi
    mv "$backup_path" "$config_path"
    printf '[ERROR] Could not create OMP config symlink; restored the previous file.\n' >&2
    exit 1
fi

if [[ -e "$config_path" ]]; then
    printf '[ERROR] OMP config path exists and is not a regular file; leaving it untouched: %s\n' "$config_path" >&2
    exit 1
fi

mkdir -p "$agent_dir"
ln -s "$repo_config" "$config_path"
printf 'Linked OMP config to %s\n' "$repo_config"
