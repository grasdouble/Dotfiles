# test_helper.bash — shared setup for all bats test files
#
# Sources main.sh without triggering the main() execution block,
# and sources prompt_for_multiselect.sh for helper function access.
#
# Usage in .bats files:
#   load 'test_helper'

# Resolve the repo root relative to this file
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Redirect LOG_FILE to /dev/null so sourcing never creates files
export LOG_FILE=/dev/null
export LOG_DIR=/tmp

# Source main.sh — BASH_SOURCE guard prevents main() from running
# shellcheck source=../main.sh
source "${REPO_ROOT}/main.sh"

# Note: prompt_for_multiselect is already sourced inside main.sh.
# toggle_option and count_selected are top-level functions defined in
# prompt_for_multiselect.sh and are directly accessible in tests.
