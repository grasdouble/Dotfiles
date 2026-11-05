#!/usr/bin/env bats

load 'test_helper'

setup() {
    TEST_ROOT="$(mktemp -d)"
    export FAKE_OMP_AGENT_DIR="${TEST_ROOT}/agent"
    mkdir -p "${TEST_ROOT}/bin" "$FAKE_OMP_AGENT_DIR"
    cat > "${TEST_ROOT}/bin/omp" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == config && "$2" == path ]] || exit 2
printf '%s\n' "$FAKE_OMP_AGENT_DIR"
EOF
    chmod +x "${TEST_ROOT}/bin/omp"
    PATH="${TEST_ROOT}/bin:${PATH}"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "links the OMP extension idempotently to the active agent directory" {
    run "$REPO_ROOT/lib/programs/omp/scripts/link_extension.sh"
    [ "$status" -eq 0 ]
    local target="${FAKE_OMP_AGENT_DIR}/extensions/dotfiles-info.ts"
    [ -L "$target" ]
    [ "$target" -ef "$REPO_ROOT/config/omp/extensions/dotfiles-info.ts" ]
    local system_prompt="${FAKE_OMP_AGENT_DIR}/APPEND_SYSTEM.md"
    [ -L "$system_prompt" ]
    [ "$system_prompt" -ef "$REPO_ROOT/config/omp/APPEND_SYSTEM.md" ]

    run "$REPO_ROOT/lib/programs/omp/scripts/link_extension.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already linked"* ]]
    [ "$system_prompt" -ef "$REPO_ROOT/config/omp/APPEND_SYSTEM.md" ]

@test "does not replace an existing OMP extension" {
    local target="${FAKE_OMP_AGENT_DIR}/extensions/dotfiles-info.ts"
    mkdir -p "$(dirname "$target")"
    printf 'local extension\n' > "$target"

    run "$REPO_ROOT/lib/programs/omp/scripts/link_extension.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"leaving it untouched"* ]]
    [ "$(<"$target")" = "local extension" ]
}
@test "does not replace an existing OMP system prompt" {
    local target="${FAKE_OMP_AGENT_DIR}/APPEND_SYSTEM.md"
    printf 'local system prompt\n' > "$target"

    run "$REPO_ROOT/lib/programs/omp/scripts/link_extension.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"leaving it untouched"* ]]
    [ "$(<"$target")" = "local system prompt" ]
}
