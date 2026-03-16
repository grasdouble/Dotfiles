#!/usr/bin/env bats
# asdf_helpers.bats — Tests for _asdf_plugin_add / _asdf_install helpers
# inside installAsdf() — Group L
#
# Strategy: run installAsdf() with external commands stubbed via PATH injection.
# A temp directory with fake executables is prepended to PATH.

load 'test_helper'

setup() {
    DRY_RUN=false
    INSTALL_RESULTS=()
    numberStep=12
    step=0
    LOG_FILE=/dev/null

    # Create a temp bin dir with stub executables
    STUB_BIN="$(mktemp -d)"
    ZSH_CALLS_FILE="$(mktemp)"
    export ZSH_CALLS_FILE

    # Stub 'brew': always succeeds silently
    printf '#!/bin/bash\nexit 0\n' > "${STUB_BIN}/brew"
    chmod +x "${STUB_BIN}/brew"

    # Default stub 'zsh': records calls, returns 0
    # Override per-test by writing a different script
    _write_zsh_stub() {
        cat > "${STUB_BIN}/zsh" << 'STUB'
#!/bin/bash
# $2 is the -c argument
echo "$2" >> "$ZSH_CALLS_FILE"
exit 0
STUB
        chmod +x "${STUB_BIN}/zsh"
    }
    _write_zsh_stub

    # Prepend stub dir to PATH
    export PATH="${STUB_BIN}:${PATH}"
}

teardown() {
    rm -rf "$STUB_BIN"
    rm -f "$ZSH_CALLS_FILE"
}

# ── Group L: _asdf_plugin_add ──────────────────────────────────────────────

@test "L1: _asdf_plugin_add skips plugin already listed by asdf" {
    # zsh stub: `asdf plugin list` returns "nodejs" → skip nodejs add
    cat > "${STUB_BIN}/zsh" << 'STUB'
#!/bin/bash
echo "$2" >> "$ZSH_CALLS_FILE"
if [[ "$2" == "asdf plugin list" ]]; then
    echo "nodejs"
    echo "pnpm"
    echo "python"
    echo "java"
fi
exit 0
STUB
    chmod +x "${STUB_BIN}/zsh"

    installAsdf

    # 'asdf plugin add nodejs' must NOT appear in calls (already listed)
    ! grep -q "asdf plugin add nodejs" "$ZSH_CALLS_FILE"
}

@test "L2: _asdf_plugin_add adds plugin when not in list" {
    # Default zsh stub: plugin list returns empty → all plugins added
    installAsdf

    grep -q "asdf plugin add nodejs" "$ZSH_CALLS_FILE"
}

@test "L3: _asdf_plugin_add logs warning and continues when add fails" {
    cat > "${STUB_BIN}/zsh" << 'STUB'
#!/bin/bash
echo "$2" >> "$ZSH_CALLS_FILE"
if [[ "$2" == asdf\ plugin\ add* ]]; then
    exit 1
fi
exit 0
STUB
    chmod +x "${STUB_BIN}/zsh"

    # Call directly (not via `run`) so INSTALL_RESULTS is visible
    installAsdf
    [[ "${INSTALL_RESULTS[0]}" == "ok|ASDF" ]]
}

# ── Group L: _asdf_install ────────────────────────────────────────────────

@test "L4: _asdf_install calls 'asdf install <plugin> <version>'" {
    installAsdf

    grep -q "asdf install nodejs" "$ZSH_CALLS_FILE"
    grep -q "asdf install pnpm"   "$ZSH_CALLS_FILE"
}

@test "L5: _asdf_install logs warning and continues when install fails" {
    cat > "${STUB_BIN}/zsh" << 'STUB'
#!/bin/bash
echo "$2" >> "$ZSH_CALLS_FILE"
if [[ "$2" == asdf\ install* ]]; then
    exit 1
fi
exit 0
STUB
    chmod +x "${STUB_BIN}/zsh"

    # Call directly so INSTALL_RESULTS is visible
    installAsdf
    [[ "${INSTALL_RESULTS[0]}" == "ok|ASDF" ]]
}

@test "L6: installAsdf dry-run does not call zsh at all" {
    DRY_RUN=true

    installAsdf
    [[ "${INSTALL_RESULTS[0]}" == "ok|ASDF" ]]

    # zsh should never have been invoked
    [[ ! -s "$ZSH_CALLS_FILE" ]]
}
