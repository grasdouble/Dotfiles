#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
repo_personal_config="${repo_root}/config/omp/config.yml"
repo_professional_config="${repo_root}/config/omp/config.professional.yml"

for config_source in "$repo_personal_config" "$repo_professional_config"; do
    if [[ ! -r "$config_source" ]]; then
        printf '[ERROR] OMP config is missing or unreadable: %s\n' "$config_source" >&2
        exit 1
    fi
done
if ! command -v omp >/dev/null 2>&1; then
    printf '[ERROR] omp is required to locate its active config directory.\n' >&2
    exit 127
fi

if [[ -n "${DOTFILES_OMP_CONFIG:-}" ]]; then
    selected_config="$DOTFILES_OMP_CONFIG"
else
    if [[ -t 0 && -r /dev/tty ]]; then
        printf 'Choose the OMP configuration: 1) Personal  2) Professional\nPress 1 or 2: ' > /dev/tty
        tty_state="$(stty -g < /dev/tty)" || {
            printf '[ERROR] Could not read terminal settings for OMP configuration selection.\n' >&2
            exit 1
        }
        restore_tty() { stty "$tty_state" < /dev/tty; }
        trap restore_tty EXIT
        stty -icanon -echo min 1 time 0 < /dev/tty
        IFS= read -r -n 1 choice < /dev/tty || {
            printf '[ERROR] Could not read OMP configuration selection.\n' >&2
            exit 1
        }
        restore_tty
        trap - EXIT
        printf '\n' > /dev/tty
    else
        printf 'Choose the OMP configuration by setting DOTFILES_OMP_CONFIG=personal or professional.\n' >&2
        exit 1
    fi
    case "$choice" in
        1) selected_config=personal ;;
        2) selected_config=professional ;;
        *) printf '[ERROR] Choose 1 (personal) or 2 (professional).\n' >&2; exit 2 ;;
    esac
fi

case "$selected_config" in
    personal) repo_config="$repo_personal_config" ;;
    professional) repo_config="$repo_professional_config" ;;
    *) printf '[ERROR] DOTFILES_OMP_CONFIG must be personal or professional.\n' >&2; exit 2 ;;
esac

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
    if [[ "$config_path" -ef "$repo_personal_config" || "$config_path" -ef "$repo_professional_config" ]]; then
        switch_path="${config_path}.dotfiles.$$"
        if ! ln -s "$repo_config" "$switch_path" || ! mv -f "$switch_path" "$config_path"; then
            rm -f "$switch_path"
            printf '[ERROR] Could not switch the active OMP config link.\n' >&2
            exit 1
        fi
        printf 'Switched OMP config to %s\n' "$repo_config"
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
    existing_config="$(<"$config_path")"
    if [[ "$existing_config" != "$(<"$repo_personal_config")" \
        && "$existing_config" != "$(<"$repo_professional_config")" ]]; then
        printf '[ERROR] Existing OMP config differs from both repository profiles; leaving it untouched.\n' >&2
        printf 'Merge its settings into the selected profile at %s, then move %s aside and rerun this script.\n' "$repo_config" "$config_path" >&2
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
