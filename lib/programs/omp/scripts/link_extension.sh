#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
repo_extension="${repo_root}/config/omp/extensions/dotfiles-info.ts"
repo_system_prompt="${repo_root}/config/omp/APPEND_SYSTEM.md"

if [[ ! -r "$repo_extension" ]]; then
    printf '[ERROR] OMP extension is missing or unreadable: %s\n' "$repo_extension" >&2
    exit 1
fi
if [[ ! -r "$repo_system_prompt" ]]; then
    printf '[ERROR] OMP system prompt is missing or unreadable: %s\n' "$repo_system_prompt" >&2
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

extension_dir="${agent_dir%/}/extensions"
target="${extension_dir}/dotfiles-info.ts"
mkdir -p "$extension_dir"

if [[ -L "$target" ]]; then
    if [[ "$target" -ef "$repo_extension" ]]; then
        printf 'OMP extension already linked to %s\n' "$repo_extension"
    else
        printf '[ERROR] Existing OMP extension symlink points elsewhere; leaving it untouched: %s\n' "$target" >&2
        exit 1
    fi
elif [[ -e "$target" ]]; then
    printf '[ERROR] OMP extension path already exists; leaving it untouched: %s\n' "$target" >&2
    exit 1
else
    ln -s "$repo_extension" "$target"
    printf 'Linked OMP extension to %s\n' "$repo_extension"
fi

system_prompt_target="${agent_dir%/}/APPEND_SYSTEM.md"
if [[ -L "$system_prompt_target" ]]; then
    if [[ "$system_prompt_target" -ef "$repo_system_prompt" ]]; then
        printf 'OMP system prompt already linked to %s\n' "$repo_system_prompt"
    else
        printf '[ERROR] Existing OMP system prompt symlink points elsewhere; leaving it untouched: %s\n' "$system_prompt_target" >&2
        exit 1
    fi
elif [[ -e "$system_prompt_target" ]]; then
    printf '[ERROR] OMP system prompt path already exists; leaving it untouched: %s\n' "$system_prompt_target" >&2
    exit 1
else
    ln -s "$repo_system_prompt" "$system_prompt_target"
    printf 'Linked OMP system prompt to %s\n' "$repo_system_prompt"
fi
