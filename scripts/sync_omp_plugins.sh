#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/config/omp/plugins.txt"
dry_run=false

usage() {
    printf 'Usage: %s [--dry-run]\n' "$0"
}

if [[ "$#" -gt 1 ]]; then
    usage >&2
    exit 2
fi
case "${1:-}" in
    "") ;;
    --dry-run) dry_run=true ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

if [[ ! -r "$manifest" ]]; then
    printf '[ERROR] OMP plugin manifest is missing or unreadable: %s\n' "$manifest" >&2
    exit 1
fi

found_plugin=false
checked_omp=false
while IFS= read -r spec || [[ -n "$spec" ]]; do
    spec="${spec%$'\r'}"
    spec="${spec#"${spec%%[![:space:]]*}"}"
    spec="${spec%"${spec##*[![:space:]]}"}"
    [[ -z "$spec" || "$spec" == \#* ]] && continue
    found_plugin=true

    if [[ "$dry_run" == true ]]; then
        printf '[DRY-RUN] omp plugin install %s\n' "$spec"
        continue
    fi
    if [[ "$checked_omp" == false ]]; then
        if ! command -v omp >/dev/null 2>&1; then
            printf '[ERROR] omp is required to install plugins from %s\n' "$manifest" >&2
            exit 127
        fi
        checked_omp=true
    fi
    if ! omp plugin install "$spec"; then
        printf '[ERROR] Could not install OMP plugin spec: %s\n' "$spec" >&2
        exit 1
    fi
done < "$manifest"

if [[ "$found_plugin" == false ]]; then
    printf 'No OMP plugins listed in %s\n' "$manifest"
fi
