#!/bin/bash

# ============================================================================
# bootstrap.sh — One-liner dotfiles installer
#
# Usage:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/noofreuuuh/Dotfiles/main/bootstrap.sh)"
#
# Or clone manually:
#   git clone https://github.com/noofreuuuh/Dotfiles.git ~/Dotfiles && cd ~/Dotfiles && bash main.sh
# ============================================================================

set -eo pipefail

REPO="https://github.com/noofreuuuh/Dotfiles.git"
DEFAULT_DEST="$(pwd)/Dotfiles"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m';   DIM='\033[2m';      RESET='\033[0m'

echo -e "${CYAN}"
echo "  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
echo "  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
echo "  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
echo "  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
echo "  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
echo "  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
echo -e "${RESET}"
echo -e "  ${BOLD}Dotfiles Bootstrap${RESET}  ${DIM}by Noofreuuuh${RESET}"
echo ""

# Check git
if ! command -v git &>/dev/null; then
    echo -e "${RED}[ERROR]${RESET} git is required. Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo -e "${DIM}Re-run this script after CLT installation completes.${RESET}"
    exit 1
fi

# Resolve installation directory
if [[ -z "${DEST:-}" ]]; then
    echo -e "  ${BOLD}Installation directory${RESET}"
    echo -e "  ${DIM}Default: ${DEFAULT_DEST}${RESET}"
    echo ""
    if [[ -t 0 ]]; then
        read -r -p "  Install here? [Y/n] " _confirm
    else
        _confirm=""
    fi
    if [[ "$_confirm" =~ ^[Nn]$ ]]; then
        while true; do
            read -r -p "  Enter path: " _custom
            # Expand ~ manually since read doesn't expand it
            _custom="${_custom/#\~/$HOME}"
            if [[ -n "$_custom" ]]; then
                DEST="$_custom"
                break
            fi
            echo -e "  ${RED}[ERROR]${RESET} Path cannot be empty."
        done
    else
        DEST="$DEFAULT_DEST"
    fi
    echo ""
fi

# Clone or update
if [[ -d "$DEST/.git" ]]; then
    echo -e "${DIM}[INFO]${RESET}  Existing repo found at ${DEST} — pulling latest..."
    if ! git -C "$DEST" pull --ff-only 2>&1; then
        echo -e "${RED}[ERROR]${RESET} git pull failed. The local repo may have uncommitted changes or a diverged branch."
        echo -e "${DIM}       To fix: cd ${DEST} && git fetch origin && git reset --hard origin/main${RESET}"
        exit 1
    fi
else
    echo -e "${DIM}[INFO]${RESET}  Cloning dotfiles to ${DEST}..."
    git clone "$REPO" "$DEST"
fi

echo ""
echo -e "${GREEN}[OK]${RESET}    Repository ready at ${BOLD}${DEST}${RESET}"
echo -e "${DIM}      Launching setup...${RESET}"
echo ""
sleep 1

bash "${DEST}/main.sh" "$@"

