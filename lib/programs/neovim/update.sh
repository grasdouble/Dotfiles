# Update Neovim's plugins and Mason-managed tools.
# Requires lib/utils/colors.sh and an initialized logging context.
updateNeovim() {
    if command -v nvim >/dev/null 2>&1; then
        if ! nvim --headless '+Lazy! sync' '+MasonToolsUpdateSync' '+qa'; then
            log_error "Neovim plugin, language server, or formatter update failed."
            return 1
        fi
    else
        log_info "Neovim is not installed — skipping Neovim updates."
    fi
}
