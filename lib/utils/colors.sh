#!/bin/bash

# ============================================================================
# COLORS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ============================================================================
# LOG FILE SETUP  (LOG_FILE is overridden in main() before any logging)
# ============================================================================
LOG_DIR="${HOME}/.dotfiles-logs"
LOG_FILE="/dev/null"

# ============================================================================
# LOGGING HELPERS
# ============================================================================
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARN]${RESET}  $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1" | tee -a "$LOG_FILE"; }
log_skip()    { echo -e "${DIM}[SKIP]${RESET}  $1 (already installed)" | tee -a "$LOG_FILE"; }
log_dry()     { echo -e "${YELLOW}[DRY-RUN]${RESET} Would run: $1"; }
log_step()    {
    echo -e "\n${BOLD}${CYAN}━━━ [${step}/${numberStep}] $1 ${RESET}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" | tee -a "$LOG_FILE"
    print_progress
}

# ============================================================================
# PROGRESS BAR
# ============================================================================
print_progress() {
    [[ $numberStep -eq 0 ]] && return
    local filled=$(( step * 30 / numberStep ))
    local empty=$(( 30 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++));  do bar+="░"; done
    echo -e "  ${CYAN}[${bar}]${RESET} ${BOLD}${step}/${numberStep}${RESET}"
}

# ============================================================================
# INSTALL RESULT TRACKING
# ============================================================================
declare -a INSTALL_RESULTS=()

track_result() {
    local name="$1"
    local status="$2"  # "ok" | "skip" | "error"
    INSTALL_RESULTS+=("${status}|${name}")
}

# ============================================================================
# BREW WRAPPER (dry-run aware)
# ============================================================================
brew_install() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "brew install $*"
    else
        brew install "$@"
    fi
}
