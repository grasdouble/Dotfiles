# Copilot Instructions

## Overview

Personal dotfiles for bootstrapping a macOS development environment. The entry point is `main.sh`, which presents an interactive multi-select menu (via `prompt_for_multiselect.sh`) to choose which components to install.

## Running the setup

```bash
# Always run from the repo root (DOTFILE_PATH is set to $PWD)
bash main.sh
```

There are no tests or linting commands — this is a shell scripting / configuration repo.

## Architecture

- **`main.sh`** — orchestrator; sources `prompt_for_multiselect.sh`, then calls install functions based on user selection
- **`prompt_for_multiselect.sh`** — reusable interactive checkbox UI for bash; takes `result_var "opt1;opt2" "default1;default2"` as arguments
- **`zsh/zshrc`** and **`zsh/zlogin`** — symlinked to `$HOME` by `installZsh()`
- **`zsh/aliases.zsh`** — sourced from `zshrc`; defines shell aliases and git utility functions
- **`zsh/custom.zsh`** — template copied (not symlinked) to `~/.custom.zsh` for personal overrides; never overwritten if it already exists
- **`asdf/default-npm-packages`** — packages auto-installed with every new Node.js version via ASDF (`express`, `neovim`, `yarn`)
- **`nvim/init.vim`** — Neovim configuration
- **`_bmad/`** — BMAD agent framework configs (agents, workflows, skills, tasks)

## Key conventions

### File linking strategy
- `zshrc` and `zlogin`: **symlinked** (`ln -s`) — changes in the repo apply immediately
- `custom.zsh`: **copied once** to `~/.custom.zsh` — protected from overwrites, for local-only customization

### macOS Apple Silicon priority
The `zshrc` always exports `/opt/homebrew/bin` first and evaluates `brew shellenv` for ARM.

### Docker setup
Docker runs via **Colima** (not Docker Desktop). Use the aliases defined in `zshrc`:
```zsh
dockerStart   # starts colima + Portainer UI
dockerStop    # stops colima
dockerUi      # opens http://localhost:9000
```

### ASDF version management
All runtimes (Node.js, pnpm, Python, Java) are managed through ASDF. The `.tool-versions` file in the repo root pins Node.js to `25.2.1`.

### Adding a new install step to `main.sh`
1. Write a function named `installXxx()` that increments `((step++))`
2. Add the label to the semicolon-separated string in the `prompt_for_multiselect` call
3. Add a `case` branch in the dispatch loop at the bottom
4. Optionally add a default selection (`true` or empty) to the defaults string
