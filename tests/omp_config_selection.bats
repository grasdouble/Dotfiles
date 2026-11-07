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

@test "links the personal config with collab auto-start enabled" {
    run env DOTFILES_OMP_CONFIG=personal "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh"
    [ "$status" -eq 0 ]
    local target="${FAKE_OMP_AGENT_DIR}/config.yml"
    [ -L "$target" ]
    [ "$target" -ef "$REPO_ROOT/config/omp/config.yml" ]
    [[ "$(<"$target")" == *$'collab:\n  autoStart: control'* ]]
}

@test "links the professional config with collab auto-start disabled" {
    run env DOTFILES_OMP_CONFIG=professional "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh"
    [ "$status" -eq 0 ]
    local target="${FAKE_OMP_AGENT_DIR}/config.yml"
    [ -L "$target" ]
    [ "$target" -ef "$REPO_ROOT/config/omp/config.professional.yml" ]
    [[ "$(<"$target")" == *$'collab:\n  autoStart: off'* ]]
}

@test "switches between the two repository-managed configs" {
    local target="${FAKE_OMP_AGENT_DIR}/config.yml"
    run env DOTFILES_OMP_CONFIG=personal "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh"
    [ "$status" -eq 0 ]

    run env DOTFILES_OMP_CONFIG=professional "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh"
    [ "$status" -eq 0 ]
    [ "$target" -ef "$REPO_ROOT/config/omp/config.professional.yml" ]
}

@test "requires a config choice for non-interactive installs" {
    run env -u DOTFILES_OMP_CONFIG "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"DOTFILES_OMP_CONFIG=personal or professional"* ]]
}

@test "prompts for and links the professional config in a terminal" {
    run env -u DOTFILES_OMP_CONFIG REPO_ROOT="$REPO_ROOT" \
        FAKE_OMP_AGENT_DIR="$FAKE_OMP_AGENT_DIR" PATH="$PATH" bash -c \
        '{ sleep 0.2; printf "2"; sleep 0.2; } | /usr/bin/script -q /dev/null bash "$REPO_ROOT/lib/programs/omp/scripts/link_config.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Choose the OMP configuration"* ]]
    [ "${FAKE_OMP_AGENT_DIR}/config.yml" -ef "$REPO_ROOT/config/omp/config.professional.yml" ]
}
