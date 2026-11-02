```
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
```

Personal macOS developer environment setup — by Noofreuuuh

## What gets installed

| Component | Description |
|-----------|-------------|
| [Homebrew](https://brew.sh/) | Package manager |
| [Git](https://git-scm.com/) | Version control — prompts for username & email |
| [Zsh + Oh My Zsh](https://ohmyz.sh/) | Shell + PowerLevel10k theme, plugins, aliases |
| [ASDF](https://asdf-vm.com/) | Runtime version manager — Node.js, pnpm, Python, Java |

Optional software bundles selectable from the interactive menu: Development, Tools, Communication, Office, Games, Others, LLM Tools, Pro Bundle. The Development bundle installs Herdr, jq, Neovim, Tree-sitter CLI, Go, and Rust. It links `config/nvim/init.lua` and configures Herdr to read `config/herdr/config.toml` through `HERDR_CONFIG_PATH`, exported by the Zsh config. Existing personal Neovim configs are preserved.

## Usage

### One-liner (new machine)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/noofreuuuh/Dotfiles/main/bootstrap.sh)"
```

The script will ask where to clone the repo, then launch the interactive setup.

### Manual

```bash
git clone https://github.com/noofreuuuh/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles
bash main.sh
```

### CLI flags

```bash
bash main.sh --dry-run              # Simulate without installing anything
bash main.sh --doctor               # Check environment health
bash main.sh --profile=core         # Install Brew + Git + Zsh + ASDF
bash main.sh --profile=dev          # core + Development bundle
bash main.sh --brew --zsh --asdf    # Pick individual components
```

### Update non-Homebrew tools

```bash
cd ~/Dotfiles
git pull --ff-only
bash main.sh --update
```

`--update` refreshes Oh My Zsh and its Git plugins, ASDF plugins and the latest Node.js/pnpm versions, declared global npm packages, Neovim plugins and Mason-managed language servers, formatters and debug adapters, Tree-sitter parsers, and the Nerd Font. It keeps the pinned Java version. It does not run Homebrew upgrades; use `brew update && brew upgrade` separately. `bash main.sh --update --dry-run` previews the update without changes.

## Neovim

Neovim 0.12+ uses `config/nvim/init.lua`, `lazy.nvim`, built-in LSP, Mason, Blink completion, Tree-sitter, Telescope, Neo-tree, Bufferline, Trouble, nvim-dap, Gitsigns, Fugitive, Conform, and Lualine. Neo-tree opens automatically as a persistent left sidebar at startup; `<leader>e` toggles it. `close_if_last_window = false` keeps Neovim open when the last file buffer is closed and only the tree remains. Start Neovim in a project directory with `nvim .` to show that project. Bufferline shows open buffers as tabs. Trouble lists diagnostics and symbols. nvim-dap provides breakpoints and a debugger UI; Mason installs adapters for JavaScript/TypeScript, Python, Go, and Rust. On first launch, lazy.nvim bootstraps its plugins, Mason installs the configured language servers, formatters and debug adapters, and Tree-sitter installs parsers. Restart Neovim after the first parser installation if highlighting is not active yet.

Configured servers: `vtsls` and ESLint for TypeScript/JavaScript, `cssls`/HTML/JSON language servers, Pyright and Ruff for Python, rust-analyzer, and gopls. Format-on-save uses Prettier for web files, Ruff for Python, rustfmt for Rust, and goimports (falling back to gofmt) for Go. The Development bundle installs Go and Rust with Homebrew.

Leader is Space. Main mappings: `<leader>e` file tree, `<leader>ff` files, `<leader>fg` project search, `<leader>bn`/`<leader>bp` next/previous buffer, `<leader>bd` close buffer, `<leader>xx` workspace diagnostics, `<leader>xX` buffer diagnostics, `<leader>cs` document symbols, `<leader>cl` LSP references/definitions, `<leader>db` breakpoint, `<leader>du` debugger UI, `<leader>dt` nearest Go test, `<F5>` continue, `<F10>` step over, `<F11>` step into, `<F12>` step out, `gd` definition, `gr` references, `K` hover, `<leader>rn` rename, `<leader>ca` code action, and `<leader>f` format. Open `:help dotfile` inside Neovim for the English guide; the French version is `:help dotfile-fr`.

## Herdr

Herdr settings and custom commands are versioned under `config/herdr/`. The top tab bar shows zoom and the clock; `Ctrl+B`, then `Shift+C` (`prefix+shift+c`) opens a tab with two split terminals. OMP session details are shown in OMP’s native Dotfiles widget instead of Herdr.

On an existing machine, pull the repository update and run `herdr server reload-config` to remove the former OMP status item. Herdr reads `HERDR_CONFIG_PATH` when its server starts; an already-running server must be restarted once to pick up the path. After that, reload TOML changes with `herdr server reload-config`.

## Oh My Pi

OMP is installed by the LLM Tools bundle. Its shared global settings are in `config/omp/config.yml`; the bundle links that file to OMP's active `config.yml` using `omp config path`, so profiles are respected without moving sessions, plugins, or caches. OMP writes persistent settings through that symlink back into the repository. Do not put credentials or machine-only values in the shared file. The status line now focuses on Vim/agent mode, host, PRs, subagents, total tokens, cost, and active time. Model, project, Git, and context details are in the Dotfiles panel; hook-status messages remain enabled.

Pinned plugins are listed in `config/omp/plugins.txt`; the LLM Tools bundle installs them. To apply a changed manifest manually, run:

```bash
bash scripts/sync_omp_plugins.sh
```

Use `bash scripts/sync_omp_plugins.sh --dry-run` to preview it. The script installs user-scope plugins from the manifest; it does not remove plugins deleted from the list, so uninstall those explicitly with `omp plugin uninstall <package>`. OMP's installed packages, `node_modules`, caches, and plugin state remain outside the repository. The current manifest has no entries because `omp plugin list` found no installed plugins.

The plugin sync script is not run by `--update`: `omp plugin install` can reset a plugin's enabled/features state when re-applied. Use it after adding or changing a pinned spec.

The LLM Tools bundle also runs `scripts/link_omp_config.sh`. An existing config identical to the repository file is preserved as a `.pre-dotfiles.*` backup before linking. A different or legacy `config.yaml` is left untouched and reported as an error; merge its settings into `config/omp/config.yml`, move the old file aside, then rerun the linker. To link manually, run `bash scripts/link_omp_config.sh`.

The repository also includes a native OMP extension in `config/omp/extensions/dotfiles-info.ts`. The LLM Tools bundle links it into the active OMP agent directory; to link it manually, run `bash scripts/link_omp_extension.sh`, then restart OMP so it loads the extension. The non-blocking, two-line widget appears automatically at session start below the editor and refreshes its session, model, provider, project, Git status, and context data every five seconds. Labels use the theme accent; clean Git status and low context usage are green, dirty Git status and 70–89% context are warnings, and context at 90% or higher is red. Use `/dotfiles-info` to hide or show it; showing it again refreshes immediately.

## Repository structure

```
bootstrap.sh                  # One-liner entry point
main.sh                       # Orchestration + interactive menu
lib/
├── colors.sh                 # Colors, log helpers, progress bar
├── ui.sh                     # Banner, prerequisites check, summary
├── doctor.sh                 # Environment health check (--doctor)
├── install_core.sh           # Brew, Git, Zsh, ASDF
├── install_software.sh       # Software bundles
└── prompt_for_multiselect.sh # Interactive checkbox menu
scripts/
├── sync_omp_plugins.sh     # Apply pinned OMP plugin specs
├── link_omp_config.sh      # Link versioned OMP settings
└── link_omp_extension.sh   # Link the native OMP information extension
config/
├── zsh/                      # Zsh config (preload, postload, aliases, p10k)
├── asdf/                     # tool-versions
├── nvim/                     # Neovim config
├── omp/                      # OMP settings, pinned plugins, and native extensions
└── herdr/                    # Herdr config and custom commands
tests/                        # Bats test suite
```

## Zsh architecture

After install, `~/.zshrc` contains two injected blocks:

- **pre-omz** — exports `DOTFILE_PATH` and sources `config/zsh/zsh_preload.zsh` (theme, plugins) before Oh My Zsh loads
- **post-omz** — sources `config/zsh/zsh_postload.zsh` (PATH, aliases, tools, p10k) at end of file

Personal overrides go in `~/.zsh_custom.zsh` — created once on first install, never overwritten.
