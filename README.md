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

The first-run shell setup installs only core prerequisites (Homebrew, Git, Zsh, ASDF, and runtimes). Individual applications, categories, and profiles are managed separately through the Ink program manager. Each category has a file in `config/programs/catalog/` with separate `cask` and `formula` arrays; the category is supplied by the index and need not be repeated on each entry. Curated profiles live in `config/programs/profiles.json`, recipe display labels in `config/programs/recipes.json`, and `config/programs.json` defines category file order.

Each program entry has an `active` boolean. Set it to `false` to keep the data while excluding the program from listings, selection, and profiles. This does not uninstall it; `remove <id>` remains available. Set it back to `true` to reactivate it.

## Usage

### One-liner (new machine)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/noofreuuuh/Dotfiles/main/bootstrap.sh)"
```

The bootstrap installs core prerequisites only. After Node.js is available, install the Ink dependencies and open the separate program manager.

### Manual setup and program manager

```bash
git clone https://github.com/noofreuuuh/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles
bash main.sh core             # Base setup: Brew, Git, Zsh, ASDF
npm ci                       # Install the Ink CLI dependencies
bash main.sh                 # Opens the separate program manager
```

`bash main.sh` delegates to Ink when its dependencies are installed. Before that, `bash main.sh core` uses the shell menu for core prerequisites only; it never installs application bundles.

The CLI requires Node.js 20 or newer. ASDF provides the configured Node.js version after core setup.

### Program manager commands

```bash
bash main.sh list
bash main.sh list --category Games
bash main.sh list --category Languages
bash main.sh install --category Games --dry-run
bash main.sh install steam visual-studio-code --dry-run
bash main.sh reinstall steam --dry-run
bash main.sh install --category Languages --dry-run
bash main.sh install --category Development --dry-run
bash main.sh install --profile pro --dry-run
bash main.sh remove steam --dry-run
bash main.sh remove steam --yes
bash main.sh profiles
bash main.sh doctor
bash main.sh update --dry-run
```

IDs and categories are listed by `list`; `list --json` emits the catalogue, Homebrew-detected install state, and installed package versions (`null` when unavailable). Run `install --category Games` to install all applications in a category, or use `install <id...>` / `install --profile <name>` for individual programs and curated profiles. Installed packages are skipped unless Homebrew's installed Cask metadata shows that an app's recorded destination differs from the catalog's `appdir`; then `install` reinstalls that Cask into the new directory. `list` marks these entries as needing reinstallation. In the Ink manager, use `←/→` to choose a category, `A` to select all its programs, then `Enter` to install; `Space` still selects individual programs. The selected program's details panel and `list` output show installed versions. Press `I`/`i` while an installed program is highlighted to reinstall it; with multiple programs selected, the same shortcut reinstalls the installed selections. The manager also supports confirmed removal; removal uses Homebrew uninstall and does not request `--zap`.

In the Ink dashboard, an installed Cask with a changed destination is marked `APPDIR OLD` in the status column and details panel. Select it and press `Enter` to reinstall it at the catalog's current `appdir`.


Colima is managed as one bundle: `install colima` and `reinstall colima` also ensure QEMU, Docker CLI, and Buildx, and add Homebrew's `lib/docker/cli-plugins` directory to `~/.docker/config.json` under `cliPluginsExtraDirs`. Removing Colima removes those formulae and only that managed directory entry; other Docker config settings are preserved.

`bash main.sh doctor`, `bash main.sh update`, and the core setup command remain separate from application management.

### Update non-Homebrew tools

```bash
cd ~/Dotfiles
git pull --ff-only
bash main.sh --update
```

`--update` refreshes Oh My Zsh and its Git plugins, ASDF plugins and the latest Node.js/pnpm versions, declared global npm packages, Neovim plugins and Mason-managed language servers, formatters and debug adapters, Tree-sitter parsers, and the Nerd Font. It keeps the pinned Java version. It does not run Homebrew upgrades; use `brew update && brew upgrade` separately. `bash main.sh --update --dry-run` previews the update without changes.

## Neovim

Neovim 0.12+ uses `config/nvim/init.lua`, `lazy.nvim`, built-in LSP, Mason, Blink completion, Tree-sitter, Telescope, Neo-tree, Bufferline, Trouble, nvim-dap, Gitsigns, Fugitive, Conform, and Lualine. Neo-tree opens automatically as a persistent left sidebar at startup; `<leader>e` toggles it. `close_if_last_window = false` keeps Neovim open when the last file buffer is closed and only the tree remains. Start Neovim in a project directory with `nvim .` to show that project. Bufferline shows open buffers as tabs. Trouble lists diagnostics and symbols. nvim-dap provides breakpoints and a debugger UI; Mason installs adapters for JavaScript/TypeScript, Python, Go, and Rust. On first launch, lazy.nvim bootstraps its plugins, Mason installs the configured language servers, formatters and debug adapters, and Tree-sitter installs parsers. Restart Neovim after the first parser installation if highlighting is not active yet.

Configured servers: `vtsls` and ESLint for TypeScript/JavaScript, `cssls`/HTML/JSON language servers, Pyright and Ruff for Python, rust-analyzer, and gopls. Format-on-save uses Prettier for web files, Ruff for Python, rustfmt for Rust, and goimports (falling back to gofmt) for Go. Go and Rust are available as Homebrew formulae in the `Languages` category.

The Neovim catalog entry bundles Homebrew's `tree-sitter-cli` formula; install and remove it with Neovim.

Leader is Space. Main mappings: `<leader>e` file tree, `<leader>ff` files, `<leader>fg` project search, `<leader>bn`/`<leader>bp` next/previous buffer, `<leader>bd` close buffer, `<leader>xx` workspace diagnostics, `<leader>xX` buffer diagnostics, `<leader>cs` document symbols, `<leader>cl` LSP references/definitions, `<leader>db` breakpoint, `<leader>du` debugger UI, `<leader>dt` nearest Go test, `<F5>` continue, `<F10>` step over, `<F11>` step into, `<F12>` step out, `gd` definition, `gr` references, `K` hover, `<leader>rn` rename, `<leader>ca` code action, and `<leader>f` format. Open `:help dotfile` inside Neovim for the English guide; the French version is `:help dotfile-fr`.

## Herdr

Herdr settings and custom commands are versioned under `config/herdr/`. The top tab bar shows zoom and the clock; `Ctrl+B`, then `Shift+C` (`prefix+shift+c`) opens a tab with two split terminals. OMP session details are shown in OMP’s native Dotfiles widget instead of Herdr.

On an existing machine, pull the repository update and run `herdr server reload-config` to remove the former OMP status item. Herdr reads `HERDR_CONFIG_PATH` when its server starts; an already-running server must be restarted once to pick up the path. After that, reload TOML changes with `herdr server reload-config`.

## Oh My Pi

OMP is installed by the LLM Tools bundle. Its shared global settings are in `config/omp/config.yml`; the bundle links that file to OMP's active `config.yml` using `omp config path`, so profiles are respected without moving sessions, plugins, or caches. OMP writes persistent settings through that symlink back into the repository. Do not put credentials or machine-only values in the shared file. The status line now focuses on Vim/agent mode, host, PRs, subagents, total tokens, cost, and active time. Model, project, Git, and context details are in the Dotfiles panel; hook-status messages remain enabled.

Pinned plugins are listed in `config/omp/plugins.txt`; the LLM Tools bundle installs them. To apply a changed manifest manually, run:

```bash
bash lib/programs/omp/scripts/sync_plugins.sh
```

Use `bash lib/programs/omp/scripts/sync_plugins.sh --dry-run` to preview it. The script installs user-scope plugins from the manifest; it does not remove plugins deleted from the list, so uninstall those explicitly with `omp plugin uninstall <package>`. OMP's installed packages, `node_modules`, caches, and plugin state remain outside the repository. The current manifest has no entries because `omp plugin list` found no installed plugins.

The plugin sync script is not run by `--update`: `omp plugin install` can reset a plugin's enabled/features state when re-applied. Use it after adding or changing a pinned spec.

The LLM Tools bundle also runs `lib/programs/omp/scripts/link_config.sh`. An existing config identical to the repository file is preserved as a `.pre-dotfiles.*` backup before linking. A different or legacy `config.yaml` is left untouched and reported as an error; merge its settings into `config/omp/config.yml`, move the old file aside, then rerun the linker. To link manually, run `bash lib/programs/omp/scripts/link_config.sh`.

The repository also includes a native OMP extension in `config/omp/extensions/dotfiles-info.ts`. The LLM Tools bundle links it into the active OMP agent directory; to link it manually, run `bash lib/programs/omp/scripts/link_extension.sh`, then restart OMP so it loads the extension. The widget shows session, model, provider, project, Git status, context usage, and the active provider's quota when OMP reports one. It uses OMP's supported custom-widget API and appears above the editor without taking keyboard focus. Context, model, session, and project data refresh on OMP turn, session, and mode events. Direct `/switch`, `/model`, `/models`, and `/effort` commands with arguments trigger a refresh after OMP applies the model or thinking-level change; changes made in interactive pickers or with `Shift+Tab` are reflected at the next turn because OMP exposes no model/thinking-level event. Git status refreshes at session start/switch/branch/tree, turn start/end, agent end, and after Bash/edit/write tool results; changes made outside OMP appear on the next such event. Quota rendering uses OMP's normalized per-provider reports, including each limit window, remaining percentage, reset time, and saved reset credits; each window is colored independently (green at 50%+ remaining, warning at 20–49%, red below 20% or when exhausted). Provider-specific APIs and credentials remain managed by OMP. Quota data refreshes at most once per minute. Use `/dotfiles-info show`, `/dotfiles-info hide`, and `/dotfiles-info refresh` to control the widget. Running `/dotfiles-info` without an option (or with an unsupported option) displays command help.

## Repository structure

```text
bootstrap.sh                  # One-liner entry point
main.sh                       # Core setup and CLI dispatcher
bin/dotfiles.mjs              # CLI entry point, argument parsing, and dispatch
bin/ui/dashboard.mjs          # Interactive program catalog and actions
package.json                  # CLI dependencies and npm scripts
config/
├── programs.json             # Ordered index of category catalogs
├── programs/
│   ├── catalog/               # One category file with cask/formula arrays
│   ├── profiles.json          # Curated install profiles
│   └── recipes.json           # Display labels for recipe IDs
├── zsh/                      # Zsh config (preload, postload, aliases, p10k)
├── asdf/                     # Runtime versions and npm globals
├── nvim/                     # Neovim config
├── omp/                      # OMP settings, pinned plugins, and extension
└── herdr/                    # Herdr config and custom commands
lib/
├── programs/
│   ├── manager.mjs           # Catalog, Homebrew inventory, install/remove
│   ├── reinstall-selection.mjs
│   ├── colima/               # Colima plus QEMU, Docker CLI, and Buildx bundle
│   ├── neovim/               # Neovim config and Tree-sitter CLI bundle recipe
│   └── omp/
│       ├── recipe.mjs         # Node lifecycle recipe
│       └── scripts/           # Shell plugin sync and config/extension links
├── utils/
│   └── colors.sh             # Shared colors, logging, progress, brew wrapper
├── ui/
│   ├── setup.sh              # Core setup UI and summaries
│   └── prompt_for_multiselect.sh
├── doctor.sh                 # Environment health check
├── install/
│   ├── brew.sh                 # Homebrew installation
│   ├── git.sh                  # Git and identity setup
│   ├── zsh.sh                  # Zsh, Oh My Zsh, plugins, shell config
│   ├── asdf.sh                 # ASDF plugins and runtimes
│   └── core_setup.sh           # Core setup menu and install orchestration
└── update.sh                 # Non-Homebrew update orchestration
tests/                        # Bats and Node CLI suites
```

## Zsh architecture

After install, `~/.zshrc` contains two injected blocks:

- **pre-omz** — exports `DOTFILE_PATH` and sources `config/zsh/zsh_preload.zsh` (theme, plugins) before Oh My Zsh loads
- **post-omz** — sources `config/zsh/zsh_postload.zsh` (PATH, aliases, tools, p10k) at end of file

Personal overrides go in `~/.zsh_custom.zsh` — created once on first install, never overwritten.
