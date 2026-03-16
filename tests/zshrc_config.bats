#!/usr/bin/env bats
# zshrc_config.bats — Static configuration tests for zsh/zsh_preload.zsh, zsh/zsh_postload.zsh and zsh/aliases.zsh
# Group M: Structural checks (no zsh needed — pure grep/pattern analysis)
#
# These tests verify structural properties of the shell config files
# without actually sourcing them (sourcing would require zsh + OMZ).

load 'test_helper'

PRELOAD="${REPO_ROOT}/config/zsh/zsh_preload.zsh"
POSTLOAD="${REPO_ROOT}/config/zsh/zsh_postload.zsh"
ALIASES="${REPO_ROOT}/config/zsh/aliases.zsh"

# ── Group M: zsh_postload.zsh structural checks ───────────────────────────

@test "M1: brew alias is guarded by -x /opt/homebrew/bin/brew check" {
    run grep -n '\-x /opt/homebrew/bin/brew' "$POSTLOAD"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-x /opt/homebrew/bin/brew"* ]]
}

@test "M2: upbrew alias is guarded (not defined unconditionally)" {
    run grep -n 'alias upbrew=' "$POSTLOAD"
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        local content="${line#*:}"
        [[ "$content" =~ ^[[:space:]] ]] || {
            echo "upbrew alias found unindented (unconditional): $line"
            return 1
        }
    done <<< "$output"
}

@test "M3: LM Studio PATH appears exactly once in zsh_postload.zsh" {
    local count
    count=$(grep -c 'lm-studio/bin' "$POSTLOAD" || true)
    [ "$count" -eq 1 ]
}

@test "M4: No hardcoded username path in zsh_postload.zsh" {
    run grep -n '/Users/noofreuuuh/' "$POSTLOAD"
    [ "$status" -ne 0 ]
}

# ── Group M: zsh_preload.zsh structural checks ────────────────────────────

@test "M5: k plugin not sourced explicitly in zsh_preload.zsh (only via plugins= array)" {
    run grep -n 'source.*k\.plugin\.zsh' "$PRELOAD"
    [ "$status" -ne 0 ]
}

@test "M6: k plugin is listed in plugins=() array in zsh_preload.zsh" {
    run grep -n '^plugins=(' "$PRELOAD"
    [ "$status" -eq 0 ]
    [[ "$output" == *" k "* || "$output" == *"(k "* || "$output" == *" k)"* ]]
}

# ── Group M: aliases.zsh structural checks ────────────────────────────────

@test "M7: git-prune-branches function is not defined in aliases.zsh" {
    run grep -n 'git-prune-branches\(\)' "$ALIASES"
    [ "$status" -ne 0 ]
}

@test "M8: gpb alias points to git-clean-branches (not git-prune-branches)" {
    run grep -n "alias gpb=" "$ALIASES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"git-clean-branches"* ]]
}

@test "M9: git_clean_branches function is defined in zsh_postload.zsh" {
    run grep -n 'git_clean_branches()' "$POSTLOAD"
    [ "$status" -eq 0 ]
}

@test "M10: zsh_preload.zsh defines ZSH_THEME as powerlevel10k" {
    run grep -n 'ZSH_THEME.*powerlevel10k' "$PRELOAD"
    [ "$status" -eq 0 ]
}

@test "M11: zsh_preload.zsh contains p10k instant prompt block" {
    run grep -n 'p10k-instant-prompt' "$PRELOAD"
    [ "$status" -eq 0 ]
}
