#!/usr/bin/env bats
# zshrc_config.bats — Static configuration tests for zsh/zshrc and zsh/aliases.zsh
# Group M: Structural checks (no zsh needed — pure grep/pattern analysis)
#
# These tests verify structural properties of the shell config files
# without actually sourcing them (sourcing would require zsh + OMZ).

load 'test_helper'

ZSHRC="${REPO_ROOT}/zsh/zshrc"
ALIASES="${REPO_ROOT}/zsh/aliases.zsh"

# ── Group M: zshrc structural checks ─────────────────────────────────────

@test "M1: brew alias is guarded by -x /opt/homebrew/bin/brew check" {
    # The alias brew=... must only appear inside an `if [[ -x /opt/homebrew/bin/brew ]]` block
    # Verify the guard exists and the alias is inside it
    run grep -n '\-x /opt/homebrew/bin/brew' "$ZSHRC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-x /opt/homebrew/bin/brew"* ]]
}

@test "M2: upbrew alias is guarded (not defined unconditionally)" {
    # alias upbrew=... must NOT appear outside an if-block
    # The alias line itself must be indented (inside the conditional block)
    run grep -n 'alias upbrew=' "$ZSHRC"
    [ "$status" -eq 0 ]
    # Strip the `linenum:` prefix from each grep result, then check for indentation
    while IFS= read -r line; do
        # Remove leading "NNN:" line-number prefix
        local content="${line#*:}"
        [[ "$content" =~ ^[[:space:]] ]] || {
            echo "upbrew alias found unindented (unconditional): $line"
            return 1
        }
    done <<< "$output"
}

@test "M3: LM Studio PATH appears exactly once in zshrc" {
    local count
    count=$(grep -c 'lm-studio/bin' "$ZSHRC" || true)
    [ "$count" -eq 1 ]
}

@test "M4: No hardcoded username path in zshrc" {
    # Should not contain /Users/<specific_user>/ paths
    run grep -n '/Users/noofreuuuh/' "$ZSHRC"
    [ "$status" -ne 0 ]
}

@test "M5: k plugin not sourced explicitly in zshrc (only via plugins= array)" {
    # The `source ... k.plugin.zsh` line must not exist
    run grep -n 'source.*k\.plugin\.zsh' "$ZSHRC"
    [ "$status" -ne 0 ]
}

@test "M6: k plugin is listed in plugins=() array" {
    run grep -n '^plugins=(' "$ZSHRC"
    [ "$status" -eq 0 ]
    [[ "$output" == *" k "* || "$output" == *"(k "* || "$output" == *" k)"* ]]
}

# ── Group M: aliases.zsh structural checks ────────────────────────────────

@test "M7: git-prune-branches function is not defined in aliases.zsh" {
    # This duplicate was removed; the canonical version lives in zshrc as git_clean_branches
    run grep -n 'git-prune-branches\(\)' "$ALIASES"
    [ "$status" -ne 0 ]
}

@test "M8: gpb alias points to git-clean-branches (not git-prune-branches)" {
    run grep -n "alias gpb=" "$ALIASES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"git-clean-branches"* ]]
}

@test "M9: git_clean_branches function is defined in zshrc" {
    run grep -n 'git_clean_branches()' "$ZSHRC"
    [ "$status" -eq 0 ]
}
