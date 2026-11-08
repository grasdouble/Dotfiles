#!/usr/bin/env bats

load 'test_helper'

setup() {
    TEST_ROOT="$(mktemp -d)"
    export REMOTE_REPO="${TEST_ROOT}/origin.git"
    export WORK_REPO="${TEST_ROOT}/work"
    git init -q --bare "$REMOTE_REPO"
    git init -q "$WORK_REPO"
    git -C "$WORK_REPO" config user.name 'Dotfiles Test'
    git -C "$WORK_REPO" config user.email 'dotfiles-test@example.invalid'
    printf 'initial\n' > "${WORK_REPO}/README.md"
    git -C "$WORK_REPO" add README.md
    git -C "$WORK_REPO" commit -q -m 'Initial commit'
    git -C "$WORK_REPO" branch -M main
    git -C "$WORK_REPO" remote add origin "$REMOTE_REPO"
    git -C "$WORK_REPO" push -q -u origin main
}

teardown() {
    rm -rf "$TEST_ROOT"
}

run_git_checkout() {
    env REPO_ROOT="$REPO_ROOT" WORK_REPO="$WORK_REPO" zsh -fc \
        'setopt aliases; source "$REPO_ROOT/config/zsh/zsh_aliases.zsh"; cd "$WORK_REPO"; eval "git-checkout $*"' \
        zsh "$@"
}

@test "fetches a remote branch locally without switching by default" {
    git --git-dir="$REMOTE_REPO" update-ref refs/heads/shared "$(git -C "$WORK_REPO" rev-parse main)"

    run run_git_checkout shared
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK_REPO" branch --show-current)" = "main" ]
    [ "$(git -C "$WORK_REPO" rev-parse --abbrev-ref --symbolic-full-name 'shared@{upstream}')" = "origin/shared" ]
}

@test "switches to a remote branch when --switch is requested" {
    git --git-dir="$REMOTE_REPO" update-ref refs/heads/shared "$(git -C "$WORK_REPO" rev-parse main)"

    run run_git_checkout --switch shared
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK_REPO" branch --show-current)" = "shared" ]
}
@test "tracks an existing origin branch" {
    git --git-dir="$REMOTE_REPO" update-ref refs/heads/shared "$(git -C "$WORK_REPO" rev-parse main)"

    run run_git_checkout --switch shared
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK_REPO" branch --show-current)" = "shared" ]
    [ "$(git -C "$WORK_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = "origin/shared" ]
}

@test "creates and pushes a branch missing from origin" {
    run run_git_checkout feature/new-work
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK_REPO" branch --show-current)" = "feature/new-work" ]
    git --git-dir="$REMOTE_REPO" show-ref --verify --quiet refs/heads/feature/new-work
    [ "$(git -C "$WORK_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = "origin/feature/new-work" ]
}
